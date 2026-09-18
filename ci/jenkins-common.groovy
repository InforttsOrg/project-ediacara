// Infortts Jenkins shared helpers — ported from ROOST manager/tenant pipeline version logic.
// COPIED INTO EACH PROJECT REPO AS <repo>/ci/jenkins-common.groovy (kept in-repo per decision).
// Load in a Jenkinsfile:  def common = load 'ci/jenkins-common.groovy'
def _sh(String cmd, boolean quiet=false) { sh(script: cmd, returnStdout: quiet)?.trim() ?: "" }

// Deploy-planning: tag-driven EPOCH.MAJOR.MINOR+PATCH, structural-vs-logic detection,
// per-track "playstore success" anchor tags (so logic-only changes don't bump Play base).
// opts:
//   label     : build node label        (mac | vps ...)
//   tagPrefix : 'manager-v' | 'tenant-v'| for infortts projects use the repo app dir e.g. '',
//               passed explicit: mitochondria → label 'mac', appDir 'apps/mitochondria'
//   appDir    : path to the app whose pubspec drives versions ('' for non-flutter)
//   track     : Play track (default 'internal')
//   isFlutter : true if structural detection ran against a pubspec.yaml
Map plan(Map opts = [:]) {
  def appDir      = opts.appDir ?: ''
  def track       = opts.track ?: env.TRACK ?: 'internal'
  def prefix      = opts.prefix ?: 'v-playstore-success-mitochondria'
  def isFlutter   = opts.isFlutter ?: appDir != ''

  // 1) Latest published version from remote tags
  def tags = _sh('git tag --list "*+[0-9]*" | sort -V | tail -n 1', true)
  def baseVer = ""; def buildNo = 0; int EPOCH=0, MAJOR=0, MINOR=0
  if (tags) {
    def v = (tags - 'v').tokenize('+')
    baseVer = v[0]; buildNo = (v.size() > 1 ? v[1] as int : 0)
    def p = baseVer.tokenize('.')
    EPOCH = p[0] as int; MAJOR = p.size()>1 ? p[1] as int : 0; MINOR = p.size()>2 ? p[2] as int : 0
  }
  echo "tags latest=${tags} base=${baseVer} build=${buildNo}"

  // 2) Most recent successful Play Store release for this track (the "anchor")
  def anchorBase = ""
  def anchorTag = _sh("git tag --list '${prefix}-${track}-*' --sort=-v:refname | head -n 1", true)
  if (anchorTag) anchorBase = anchorTag.tokenize('-').last()
  echo "anchor(${track})=${anchorBase} (tag ${anchorTag})"

  // 3) Structural change detection vs the anchor (sticky-base avoidance)
  def cmpTag = anchorTag ?: tags
  def structural = false
  if (appDir && cmpTag) {
    def changedFiles = _sh("git diff --name-only '${cmpTag}'..HEAD -- '${appDir}'", true)
    if (appDir) {
      for (String f : changedFiles.tokenize()) {
        if (!(f =~ /(^|\/)(pubspec.yaml|VERSION|VERSIONS.md|CHANGELOG.md|\.env\.example|README\.md|CHANGELOG)$/)) { structural = true; break }
        if (f.endsWith('pubspec.yaml')) {
          def d = _sh("git diff '${cmpTag}'..HEAD -- '${f}' | grep '^+' | grep -vE '^\\+\\+\\+|\\s*version:|\\s*\"version\"' | grep -q '^+' && echo yes", true)
          if (d == 'yes') { structural = true; break }
        }
      }
    }
  }

  // 4) Next build number — same formula as InforttsVersionHelper: epoch*10000 + major*100 + minor
  def nextBuild = buildNo > 0 ? buildNo + 1 : (EPOCH*10000 + MAJOR*100 + MINOR)

  def decision = [:]
  def action    = (structural) ? 'playstore' : 'ota'
  def reason    = (structural) ? "Structural change in ${appDir}" : 'Logic-only change'

  // 5) Base version for this release
  def newBase = ""
  if (structural) {
    newBase = "${EPOCH}.${MAJOR+1}.0"
    if (MAJOR+1 >= 100) newBase = "${EPOCH+1}.0.0"
  } else if (anchorBase) {
    newBase = anchorBase                              // stick to what's already live on Play
  } else {
    newBase = baseVer ?: "${EPOCH}.0.0"
  }
  def newVersion = "${newBase}+${nextBuild}"

  // 6) OTA-only base suffices when logic-only AND a Play base exists: registry bump on same base
  if (!structural && anchorBase) {
    action = 'ota'
    reason = "Logic-only change parked on Play base ${anchorBase}; OTA registry bump only"
  }

  echo "    PLAN: version=${newVersion} base=${newBase} build=${nextBuild}"
  echo "    ACTION: ${action} — ${reason}"
  return [
    new_version: newVersion, base_version: newBase, build_number: "${nextBuild}",
    action: action, reason: reason, track: track, structural: structural,
  ]
}

// Tag the repo with success markers (same family as v-playstore-success-{app}-{track}-{base}).
void tag(String kind, Map p, String tokenUser='', String tokenPass='') {
  def tagName = "${kind}-${p.track}-${p.base_version}"
  _sh("git tag -f '${tagName}' && git push origin '${tagName}' --force")
  echo "tagged ${tagName}"
}

// Telegram/console notify shim.
void notify(String msg, Map opts=[:]) {
  echo "[CI] ${msg}"
  // Optional: hook to your existing telegram pipeline: curl -s -X POST https://api.telegram.org/bot<TOKEN>/sendMessage -d chat_id=<> -d text="${msg}"
}

// OTA registry bump (mitochondria-style): no patch artifact needed when latestPatch=0.
void otaBump(Map p) {
  echo "OTA bump to ${p.new_version} (base ${p.base_version}, build ${p.build_number})"
  writeFile file: 'ota-release.json', text: groovy.json.JsonOutput.toJson([
    version: p.new_version, base_version: p.base_version, latest_build: p.build_number as int,
    latest_patch: 0, published_at: new Date().toInstant().toString()])
}

return this