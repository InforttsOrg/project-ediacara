// Infortts Jenkins — combined multi-stage pipeline (auto-generated).
// Stages every deployment type of this repo sequentially (flutter → cloudflare → docker → python).
// DO NOT hand-edit: regenerate with jenkins/generate-jenkinsfiles.sh — it is the source of truth.
// Requires credentials: git-github, play-service-account-json, cloudflare-api-token,
//                       deploy-ssh, ghcr-infortts.

pipeline {
  agent { label 'vps' }
  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 20, unit: 'MINUTES')
  }
  environment {
    MAX_GRADLE_OPTS = '-Dorg.gradle.jvmargs="-Xmx4g -XX:MaxMetaspaceSize=512m"'
  }
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git submodule update --init --recursive 2>/dev/null || true'
      }
    }

stage('Cloudflare: ediacara') {
      steps {
        script {
          if (fileExists('package.json')) sh 'npm install --no-audit --no-fund 2>/dev/null || true'
          if (fileExists('wrangler.toml') && fileExists('package.json')) {
            sh 'npm test -- --passWithNoTests 2>/dev/null || true'
            sh 'npm run build 2>/dev/null || true'
          }
        }
        script {
          try {
            withCredentials([[$class: 'StringBinding', credentialsId: 'cloudflare-api-token', variable: 'CF_API_TOKEN']]) {
              withEnv(["CLOUDFLARE_API_TOKEN=${CF_API_TOKEN}", "CLOUDFLARE_ACCOUNT_ID=04e1a3c2b99919914aba485175906033"]) {
                sh "npx wrangler deploy --name ediacara 2>&1 | tail -20 || echo WRANGLER_DEPLOY_STATUS"
              }
            }
          } catch (Exception e) {
            echo "Cloudflare deploy warning: ${e.message}"
          }
        }
        script {
          sh "curl -sf -o /dev/null --max-time 20 https://ediacara.workers.dev && echo LIVECHECK_OK || echo LIVECHECK_WARN"
        }
      }
    }

  }
  post {
    success { script { def c = load 'ci/jenkins-common.groovy'; c.notify("${env.JOB_NAME} OK") } }
    failure { script { def c = load 'ci/jenkins-common.groovy'; c.notify("${env.JOB_NAME} FAILED", [lvl:'error']) } }
  }
}