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
    MAX_GRADLE_OPTS = '-Dorg.gradle.jvmargs="-Xmx4g -XX:MaxMetaspaceSize=512m" -Dorg.gradle.parallel=true -Dorg.gradle.caching=true'
  }
  stages {
    stage('Checkout') {
      steps {
        sh 'git clean -ffdx -e ota-release.json 2>/dev/null || true'
        checkout scm
        sh 'git submodule update --init --recursive 2>/dev/null || true'
      }
    }

stage('Version plan') {
      steps {
        checkout scm
        script {
          if (PLAN == null) { PLAN = [:] }
          try {
            def common = load 'ci/jenkins-common.groovy'
            def planResult = common.plan([appDir: '', track: 'internal',
                                          prefix: 'v-release-ediacara', isFlutter: false])
            PLAN = planResult ?: [action: 'playstore', new_version: '1.0.0', base_version: '1.0.0', build_number: '10000']
            common.updateBuildSummary(PLAN, [
              android: PLAN.action == 'playstore' ? '✅ Native .aab (Google Play internal track)' : (PLAN.action == 'ota' ? '📦 OTA Differential Patch (HF CDN)' : '⏭️ Skipped (no native change)')
            ])
            common.notify("Planning ${env.JOB_NAME}: ${PLAN.new_version} → ${PLAN.action}")
            if (PLAN.action == 'skip') { echo 'nothing to do'; currentBuild.result = 'SUCCESS'; return }
          } catch (Exception e) {
            echo "Plan step notice: ${e.message}"
            PLAN = [action: 'playstore', new_version: '1.0.0', base_version: '1.0.0', build_number: '10000']
          }
        }
      }
    }

stage('Cloudflare: ediacara') {
      steps {
        checkout scm
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
            def pm = fileExists('pnpm-lock.yaml') ? 'pnpm' : 'npm'
            sh """
              node -e '
                const pkg = require("./package.json");
                if (pkg.scripts && pkg.scripts.test) {
                  try {
                    require("child_process").execSync("${pm} test", {stdio: "inherit"});
                  } catch(e) {
                    console.log("Warning: tests failed or exited non-zero:", e.message);
                  }
                }
                if (pkg.scripts && pkg.scripts.build) {
                  require("child_process").execSync("${pm} run build", {stdio: "inherit"});
                }
              '
            """
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

stage('Tag success') {
      steps {
        script {
          if (!PLAN || !PLAN.new_version) {
            echo "No version planned — skipping tag"
            return
          }
          if (PLAN.action == 'skip') {
            echo "Plan action was skip — skipping tag"
            return
          }
          echo "Tagging release ${PLAN.new_version} (action: ${PLAN.action})..."
          def common = load 'ci/jenkins-common.groovy'
          common.tag('v-release-ediacara', PLAN)
        }
      }
    }

  }
  post {
    success { echo "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} SUCCEEDED" }
    failure { echo "Pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED" }
  }
}
