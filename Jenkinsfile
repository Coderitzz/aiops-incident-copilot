// Declarative pipeline: lint, test, build, scan, push to ECR, deploy with Helm.
// Runs on the CI host (Docker, AWS CLI, kubectl, Helm and Trivy installed by Ansible).
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 40, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '15'))
  }

  // Jenkins is private, so GitHub cannot call a webhook; poll instead.
  triggers { pollSCM('H/5 * * * *') }

  environment {
    AWS_REGION  = 'ap-south-1'
    ECR_PROJECT = 'aiops'
    SERVICES    = 'frontend order-service payment-service inventory-service'
    NAMESPACE   = 'aiops'
    RELEASE     = 'aiops'
  }

  stages {
    stage('Prepare') {
      steps {
        script {
          env.GIT_SHA    = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.IMAGE_TAG  = "${env.BUILD_NUMBER}-${env.GIT_SHA}"
          env.ACCOUNT_ID = sh(returnStdout: true, script: 'aws sts get-caller-identity --query Account --output text').trim()
          env.REGISTRY   = "${env.ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
        }
        echo "Image tag ${env.IMAGE_TAG}, registry ${env.REGISTRY}"
      }
    }

    stage('Lint and test') {
      steps {
        sh '''
          docker run --rm --user "$(id -u):$(id -g)" \
            -e HOME=/tmp -e PYTHONDONTWRITEBYTECODE=1 \
            -v "$PWD:/work" -w /work \
            python:3.12-slim bash scripts/ci_test.sh
        '''
      }
    }

    stage('Build images') {
      steps {
        sh '''
          for s in $SERVICES; do
            docker build --build-arg SERVICE=$s -t $REGISTRY/$ECR_PROJECT/$s:$IMAGE_TAG services
          done
        '''
      }
    }

    stage('Scan with Trivy') {
      steps {
        // Fail the build on CRITICAL findings that have a fix available
        sh '''
          for s in $SERVICES; do
            trivy image --no-progress --exit-code 1 --severity CRITICAL --ignore-unfixed \
              $REGISTRY/$ECR_PROJECT/$s:$IMAGE_TAG
          done
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY
          for s in $SERVICES; do
            docker push $REGISTRY/$ECR_PROJECT/$s:$IMAGE_TAG
          done
        '''
      }
    }

    stage('Deploy with Helm') {
      steps {
        sh '''
          kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

          # ECR tokens last 12 hours, so refresh the pull secret on every deploy
          kubectl -n $NAMESPACE create secret docker-registry ecr-pull \
            --docker-server=$REGISTRY --docker-username=AWS \
            --docker-password="$(aws ecr get-login-password --region $AWS_REGION)" \
            --dry-run=client -o yaml | kubectl apply -f -

          helm upgrade --install $RELEASE k8s/charts/aiops \
            --namespace $NAMESPACE \
            --set image.registry=$REGISTRY/$ECR_PROJECT \
            --set image.tag=$IMAGE_TAG \
            --atomic --timeout 5m
        '''
      }
    }

    stage('Verify') {
      steps {
        sh '''
          kubectl -n $NAMESPACE get pods -o wide
          for s in $SERVICES; do
            kubectl -n $NAMESPACE rollout status deployment/$s --timeout=120s
          done
        '''
      }
    }
  }

  post {
    always  { sh 'docker image prune -f || true' }
    success { echo "Deployed ${env.IMAGE_TAG}" }
    failure { echo 'Build failed. A failed helm upgrade rolls back automatically (--atomic).' }
  }
}
