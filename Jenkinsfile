pipeline {
  agent {
    label 'agent'
  }

  options {
    timestamps()
    ansiColor('xterm')
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'FLOCI_ENDPOINT',              defaultValue: 'http://192.168.251.1:4566',              description: 'Remote Floci endpoint')
    string(name: 'POLICY_REPO_URL',             defaultValue: 'https://github.com/maxlam96/tf-policy-repo.git', description: 'OPA policy repository URL')
    string(name: 'POLICY_REPO_BRANCH',          defaultValue: 'main',                                   description: 'OPA policy repository branch')
    string(name: 'POLICY_REPO_CREDENTIALS_ID',  defaultValue: 'maxlam96',                               description: 'Jenkins credentials ID for the OPA policy repository')
    string(name: 'NETWORK_APPROVERS',           defaultValue: 'network-team',                           description: 'Jenkins users/groups allowed to approve VPC creation')
    choice(name: 'ENV',                         choices: ['staging', 'production'],                     description: 'Terraform environment')
    booleanParam(name: 'RUN_APPLY',             defaultValue: false,                                    description: 'Apply to Floci after OPA passes')
  }

  environment {
    TF_DIR              = 'floci-vpc'
    POLICY_CHECKOUT_DIR = 'tf-policy-repo'
    POLICY_DIR          = 'tf-policy-repo/policy'
    REPORT_DIR          = 'reports'
    AWS_ACCESS_KEY_ID       = 'test'
    AWS_SECRET_ACCESS_KEY   = 'test'
    AWS_DEFAULT_REGION      = 'ap-southeast-1'
    AWS_ENDPOINT_URL        = "${params.FLOCI_ENDPOINT}"
    TF_IN_AUTOMATION        = 'true'
  }

  stages {

    stage('Checkout Policy Repo') {
      steps {
        dir("${env.POLICY_CHECKOUT_DIR}") {
          git branch: "${params.POLICY_REPO_BRANCH}",
              credentialsId: "${params.POLICY_REPO_CREDENTIALS_ID}",
              url: "${params.POLICY_REPO_URL}"
        }
      }
    }

    stage('Floci Health Check') {
      steps {
        sh '''
          set -eu
          echo "Checking Floci at ${AWS_ENDPOINT_URL}"
          curl -fsS "${AWS_ENDPOINT_URL}/_localstack/health" || curl -fsS "${AWS_ENDPOINT_URL}"
        '''
      }
    }

    stage('Terraform Validate') {
      steps {
        dir("${env.TF_DIR}") {
          sh 'terraform fmt -check -recursive'
          sh 'terraform init -input=false'
          sh 'terraform validate'
        }
      }
    }

    stage('Terraform Plan') {
      steps {
        dir("${env.TF_DIR}") {
          sh '''
            terraform plan \
              -refresh=false \
              -out=tfplan \
              -var="floci_endpoint=${AWS_ENDPOINT_URL}" \
              -var-file=envs/${ENV}.tfvars
            terraform show -json tfplan > plan.json
          '''
        }
      }
    }

    stage('Network Approval For VPC') {
      steps {
        sh '''
          set -eu
          mkdir -p .opa-data
          printf '{"change_request":{"submitted_by_team":"not-network"}}\n' > .opa-data/change-request.json
        '''
        script {
          def hasVpcCreate = sh(
            returnStatus: true,
            script: '''
              jq -e '.resource_changes[]? | select(.mode == "managed" and .type == "aws_vpc" and (.change.actions | index("create")))' "${TF_DIR}/plan.json" >/dev/null
            '''
          ) == 0

          if (hasVpcCreate) {
            input message: "Terraform plan creates a VPC. Network team approval is required.",
                  submitter: "${params.NETWORK_APPROVERS}"
            writeFile file: '.opa-data/change-request.json',
                      text: '{"change_request":{"submitted_by_team":"network"}}\n'
          }
        }
      }
    }

    stage('OPA Policy Check') {
      steps {
        sh '''
          set -eu
          mkdir -p "${REPORT_DIR}" .opa-data

          # Nếu network approval bị skip → tạo default file để OPA không lỗi
          if [ ! -f .opa-data/change-request.json ]; then
            printf '{"change_request":{"submitted_by_team":"not-network"}}\n' > .opa-data/change-request.json
          fi

          echo "===== OPA policy check: JSON report ====="
          set +e
          conftest test "${TF_DIR}/plan.json" \
            --policy "${POLICY_DIR}" \
            --all-namespaces \
            --data "${POLICY_DIR}/exceptions/allowlist.json" \
            --data "${POLICY_DIR}/environments/${ENV}.json" \
            --data ".opa-data/change-request.json" \
            --output json > "${REPORT_DIR}/jenkins-opa-${ENV}.json"
          OPA_STATUS=$?

          echo "===== OPA policy check: console table ====="
          conftest test "${TF_DIR}/plan.json" \
            --policy "${POLICY_DIR}" \
            --all-namespaces \
            --data "${POLICY_DIR}/exceptions/allowlist.json" \
            --data "${POLICY_DIR}/environments/${ENV}.json" \
            --data ".opa-data/change-request.json" \
            --output table || true

          echo "===== OPA policy check: summary ====="
          jq -r '
            .[] |
            "namespace=" + (.namespace // "-") +
            " success=" + ((.successes // []) | length | tostring) +
            " warnings=" + ((.warnings // []) | length | tostring) +
            " failures=" + ((.failures // []) | length | tostring) +
            " exceptions=" + ((.exceptions // []) | length | tostring)
          ' "${REPORT_DIR}/jenkins-opa-${ENV}.json" || true

          set -e
          exit "${OPA_STATUS}"
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'reports/jenkins-opa-*.json, floci-vpc/plan.json',
                           allowEmptyArchive: true
        }
        unsuccessful {
          echo 'OPA blocked this run. Check archived jenkins-opa report.'
        }
      }
    }

    stage('Archive Policy Report') {
      steps {
        archiveArtifacts artifacts: 'reports/jenkins-opa-*.json, floci-vpc/plan.json',
                         allowEmptyArchive: true
      }
    }

    stage('Apply To Floci') {
      when {
        allOf {
          expression { return params.RUN_APPLY }
          anyOf {
            branch 'main'
            expression { return env.GIT_BRANCH == 'origin/main' || env.BRANCH_NAME == null }
          }
        }
      }
      steps {
        input message: "OPA passed. Apply Terraform to Floci ${params.FLOCI_ENDPOINT}?"
        dir("${env.TF_DIR}") {
          sh 'terraform apply -input=false tfplan'
        }
      }
    }
  }
}
