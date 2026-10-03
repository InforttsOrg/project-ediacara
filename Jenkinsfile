// Infortts Jenkins — combined multi-stage pipeline (auto-generated).
// Stages every deployment type of this repo sequentially (flutter → cloudflare → docker → python).
// DO NOT hand-edit: regenerate with jenkins/generate-jenkinsfiles.sh — it is the source of truth.
// Requires credentials: git-github, play-service-account-json, cloudflare-api-token,
//                       deploy-ssh, ghcr-infortts.

import groovy.transform.Field

@Field def PLAN = [:]

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
        sh 'git clean -ffdx -e ota-release.json 2>/dev/null || true'
        checkout scm
        sh 'git submodule update --init --recursive 2>/dev/null || true'
      }
    }

stage('Cloudflare: ediacara') {
      steps {
        script {
          // pnpm-aware, fail-closed install. The 'vps' label is the controller's
          // built-in node, whose image may not ship pnpm — self-heal via npm.
          if (fileExists('pnpm-lock.yaml')) {
            sh '''
              set -e
              if ! command -v pnpm >/dev/null 2>&1; then
                echo "pnpm not found — installing via npm"
                npm install -g pnpm@9 >/dev/null 2>&1
              fi
              pnpm --version
              pnpm install --frozen-lockfile
            '''
          } else if (fileExists('package.json')) {
            sh 'npm install --no-audit --no-fund'
          }
        }
        script {
          if ((fileExists('wrangler.toml') || fileExists('wrangler.jsonc')) && fileExists('package.json')) {
            // Fail closed: a failing test/build must fail the build, not be
            // swallowed by `|| true` as before.
            def pm = fileExists('pnpm-lock.yaml') ? 'pnpm' : 'npm'
            sh "${pm} test -- --passWithNoTests"
            sh "${pm} run build"
          }
        }
        script {
          withCredentials([[$class: 'StringBinding', credentialsId: 'cloudflare-api-token', variable: 'CF_API_TOKEN']]) {
            withEnv(["CLOUDFLARE_API_TOKEN=${CF_API_TOKEN}", "CLOUDFLARE_ACCOUNT_ID=04e1a3c2b99919914aba485175906033"]) {
              // pipefail: a bare `deploy | tail` returns tail's exit code (0),
              // masking deploy failures. No `|| echo` — a failed deploy fails
              // the build instead of shipping a broken Worker.
              sh "set -o pipefail; npx wrangler deploy --name ediacara 2>&1 | tail -20"
            }
          }
        }
        script {
          def liveCheck = sh(script: "curl -sf -o /dev/null --max-time 20 https://ediacara.infortts.workers.dev && echo LIVECHECK_OK || echo LIVECHECK_WARN", returnStdout: true)?.trim()
          try {
            def common = load 'ci/jenkins-common.groovy'
            common.updateBuildSummary([action: 'cloudflare', new_version: "worker-ediacara-${BUILD_NUMBER}"], [
              web: "✅ Cloudflare Worker (https://ediacara.infortts.workers.dev)",
              backend: "Cloudflare Edge",
              health: liveCheck == 'LIVECHECK_OK' ? "🟢 LIVECHECK_OK" : "⚠️ LIVECHECK_WARN (advisory)"
            ])
          } catch (Exception e) {
            echo "Cloudflare summary notice: ${e.message}"
          }
        }
      }
    }

  }
  post {
    success { echo "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} SUCCEEDED" }
    failure { echo "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED" }
  }
}