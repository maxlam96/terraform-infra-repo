pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    disableConcurrentBuilds()
  }

  parameters {
    string(name: 'FLOCI_ENDPOINT', defaultValue: 'http://192.168.251.1:4566', description: 'Remote Floci endpoint')
    string(name: 'POLICY_REPO_URL', defaultValue: 'https://github.com/maxlam96/tf-policy-repo.git', description: 'OPA policy repository URL')
    string(name: 'POLICY_REPO_BRANCH', defaultValue: 'main', description: 'OPA policy repository branch')
    string(name: 'NETWORK_APPROVERS', defaultValue: 'network-team', description: 'Jenkins users/groups allowed to approve VPC creation')
    choice(name: 'ENV', choices: ['staging', 'production'], description: 'Terraform environment')
    booleanParam(name: 'RUN_APPLY', defaultValue: false, description: 'Apply to Floci after OPA passes')
  }

  environment {
    TF_DIR = 'floci-vpc'
    POLICY_CHECKOUT_DIR = 'tf-policy-repo'
    POLICY_DIR = 'tf-policy-repo/policy'
    REPORT_DIR = 'reports'
    AWS_ACCESS_KEY_ID = 'test'
    AWS_SECRET_ACCESS_KEY = 'test'
    AWS_DEFAULT_REGION = 'ap-southeast-1'
    AWS_ENDPOINT_URL = "${params.FLOCI_ENDPOINT}"
    TF_IN_AUTOMATION = 'true'
    SUBMITTING_TEAM = 'unknown'
  }

  stages {
    stage('Checkout Policy Repo') {
      steps {
        dir("${env.POLICY_CHECKOUT_DIR}") {
          git branch: "${params.POLICY_REPO_BRANCH}", url: "${params.POLICY_REPO_URL}"
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
            env.SUBMITTING_TEAM = 'network'
          } else {
            env.SUBMITTING_TEAM = 'not-network'
          }
        }
      }
    }

    stage('OPA Policy Check') {
      steps {
        sh '''
          set -eu
          mkdir -p "${REPORT_DIR}"
          mkdir -p .opa-data
          printf '{"change_request":{"submitted_by_team":"%s"}}\n' "${SUBMITTING_TEAM}" > .opa-data/change-request.json
          conftest test "${TF_DIR}/plan.json" \
            --policy "${POLICY_DIR}" \
            --all-namespaces \
            --data "${POLICY_DIR}/exceptions/allowlist.json" \
            --data "${POLICY_DIR}/environments/${ENV}.json" \
            --data ".opa-data/change-request.json" \
            --output json > "${REPORT_DIR}/jenkins-opa-${ENV}.json"
        '''
      }
      post {
        unsuccessful {
          echo 'OPA blocked this run. Check archived jenkins-opa report.'
        }
      }
    }

    stage('Archive Policy Report') {
      steps {
        archiveArtifacts artifacts: 'reports/jenkins-opa-*.json, floci-vpc/plan.json', allowEmptyArchive: true
      }
    }

    stage('Apply To Floci') {
      when {
        allOf {
          branch 'main'
          expression { return params.RUN_APPLY }
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
