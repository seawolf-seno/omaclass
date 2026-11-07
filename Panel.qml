import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// OmaClass: the teacher's classroom controls, one click from the bar.
// Class-wide actions on top, the students below, the full Veyon view one
// button away. All Veyon traffic goes through bin/omaclass-veyon.
Panel {
  id: root
  moduleName: "omaclass"
  ipcTarget: "omaclass"

  // ---- Glyphs (JetBrainsMono Nerd Font, Material Design range) ----------
  readonly property string iconClass: String.fromCodePoint(0xf0474)
  readonly property string iconLock: String.fromCodePoint(0xf033e)
  readonly property string iconUnlock: String.fromCodePoint(0xf0fc6)
  readonly property string iconMessage: String.fromCodePoint(0xf0361)
  readonly property string iconWeb: String.fromCodePoint(0xf059f)
  readonly property string iconPresent: String.fromCodePoint(0xf1483)
  readonly property string iconGrid: String.fromCodePoint(0xf0570)
  readonly property string iconSend: String.fromCodePoint(0xf048a)
  readonly property string iconNext: String.fromCodePoint(0xf0140)
  readonly property string iconMastery: String.fromCodePoint(0xf0128)

  // ---- Look ---------------------------------------------------------------
  readonly property color foreground: Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- State --------------------------------------------------------------
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("bin/omaclass-veyon")).replace(/^file:\/\//, ""))
  property bool sampleMode: String(setting("sampleClass", false)) === "true"
  property var loadedClasses: []
  property string classSource: ""       // "omamastery" when OmaMastery supplies the classes
  property bool classPicked: false      // the teacher chose a class since opening the panel
  property int classIndex: 0
  property var status: ({})
  property var lockedClasses: ({})
  property string composer: ""          // "", "message" or "website"
  property string feedback: ""
  property bool busy: false
  property string pendingVerb: ""
  property string pendingAction: ""

  // Sample mode uses OmaMastery's made-up classes when there are any, so a
  // demo shows the same class in both apps; otherwise a built-in one.
  readonly property var classes: {
    // Real mode: every class, with the real computers in its Veyon room.
    if (!sampleMode) return loadedClasses
    var samples = loadedClasses.filter(function(c) { return c.sample === true }).map(Model.asSample)
    return samples.length > 0 ? samples : [Model.sampleClass()]
  }
  readonly property bool hasMastery: classSource === "omamastery"
  readonly property var currentClass: classes.length > 0 ? classes[Math.min(classIndex, classes.length - 1)] : null
  readonly property var online: Model.onlineHosts(currentClass, status)
  readonly property bool locked: currentClass ? lockedClasses[currentClass.name] === true : false
  readonly property bool hasClass: currentClass !== null && currentClass.computers.length > 0

  readonly property string metaText: {
    if (!currentClass) return "NO CLASS SET UP YET"
    var text = online.length + " OF " + currentClass.computers.length + " ONLINE"
    if (locked) text += " · LOCKED"
    return sampleMode ? "SAMPLE · " + text : text
  }

  onSampleModeChanged: { feedback = ""; composer = ""; classPicked = false; refresh() }
  onOpenedChanged: if (opened) { classPicked = false; refresh() }
  onClassesChanged: {
    // Land on the class happening now (or next) unless the teacher moved.
    if (!classPicked) classIndex = Model.nowIndex(classes)
    if (sampleMode) status = Model.sampleStatus(currentClass)
  }

  function refresh() {
    if (!classesProc.running) classesProc.running = true
  }

  function checkStatus() {
    if (sampleMode || !currentClass || statusProc.running) return
    var hosts = Model.allHosts(currentClass)
    if (hosts.length === 0) return
    statusProc.command = ["python3", "-I", helper, "status"].concat(hosts)
    statusProc.running = true
  }

  function setLocked(value) {
    var next = Object.assign({}, lockedClasses)
    next[currentClass.name] = value
    lockedClasses = next
  }

  function flash(text) {
    feedback = text
    feedbackTimer.restart()
  }

  // Run one Veyon feature on every online computer in the class.
  function act(op, feature, argsJson, verb) {
    if (!hasClass || busy) return
    if (online.length === 0) { flash("No one is online"); return }
    if (sampleMode) {
      if (feature === "ScreenLock") setLocked(op === "start")
      flash(Model.resultText(verb, online.length, 0, true))
      return
    }
    busy = true
    pendingVerb = verb
    pendingAction = op + ":" + feature
    feedback = verb + "…"
    runProc.command = ["python3", "-I", helper, "run", op, feature, argsJson || "{}"].concat(online)
    runProc.running = true
  }

  function toggleLock() {
    if (locked) act("stop", "ScreenLock", "{}", "Unlocked")
    else act("start", "ScreenLock", "{}", "Locked")
  }

  function openComposer(kind) {
    composer = composer === kind ? "" : kind
    feedback = ""
  }

  function submitComposer(text) {
    if (composer === "message") {
      var args = Model.messageArgs(text)
      if (args === "") return
      act("start", "TextMessage", args, "Sent to")
    } else if (composer === "website") {
      var site = Model.websiteArgs(text)
      if (site === "") { flash("That doesn't look like a web address"); return }
      act("start", "OpenWebsite", site, "Opened on")
    }
    composer = ""
  }

  function viewStudent(computer) {
    if (sampleMode) { flash("Sample class: this opens " + computer.name + "'s screen"); return }
    if (status[computer.host] !== true) { flash(computer.name + " is offline"); return }
    Quickshell.execDetached(["veyon-cli", "remoteaccess", "view", computer.host])
  }

  function controlStudent(computer) {
    if (sampleMode) { flash("Sample class: this takes control of " + computer.name + "'s screen"); return }
    if (status[computer.host] !== true) { flash(computer.name + " is offline"); return }
    Quickshell.execDetached(["veyon-cli", "remoteaccess", "control", computer.host])
  }

  function openFullView() {
    close()
    Quickshell.execDetached(["veyon-master"])
  }

  function openMastery() {
    close()
    var id = currentClass && currentClass.id ? String(currentClass.id) : ""
    Quickshell.execDetached(id ? ["omamastery", "open", id] : ["omamastery"])
  }

  function nextClass() {
    if (classes.length < 2) return
    classPicked = true
    classIndex = (classIndex + 1) % classes.length
    if (sampleMode) status = Model.sampleStatus(currentClass)
    composer = ""
    feedback = ""
    checkStatus()
  }

  // ---- Processes ----------------------------------------------------------
  Process {
    id: classesProc
    command: ["python3", "-I", root.helper, "classes"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = Model.parseJson(text)
        root.classSource = data && data.source === "omamastery" ? "omamastery" : ""
        root.loadedClasses = data && Array.isArray(data.classes) ? data.classes.slice(0, 32) : []
        root.checkStatus()
      }
    }
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = Model.parseJson(text)
        if (data && data.hosts && typeof data.hosts === "object") root.status = data.hosts
      }
    }
  }

  Process {
    id: runProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = Model.parseJson(text)
        root.busy = false
        if (!data || data.ok !== true) {
          root.flash("Couldn't reach Veyon" + (data && data.error ? ": " + String(data.error).slice(0, 80) : ""))
          return
        }
        var done = Array.isArray(data.done) ? data.done.length : 0
        var failed = Array.isArray(data.failed) ? data.failed.length : 0
        if (done > 0 && root.pendingAction === "start:ScreenLock") root.setLocked(true)
        if (done > 0 && root.pendingAction === "stop:ScreenLock") root.setLocked(false)
        root.flash(Model.resultText(root.pendingVerb, done, failed, false))
      }
    }
    onExited: function(code) { if (code !== 0) root.busy = false }
  }

  Timer {
    interval: Math.max(5, Number(root.setting("refreshIntervalSec", 10))) * 1000
    running: root.opened && !root.sampleMode
    repeat: true
    onTriggered: root.checkStatus()
  }

  Timer {
    id: feedbackTimer
    interval: 5000
    onTriggered: if (!root.busy) root.feedback = ""
  }

  // ---- Bar button ---------------------------------------------------------
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.locked ? root.iconLock : root.iconClass
    tooltipText: ""
    onPressed: function(b) { root.toggle() }
  }

  // ---- Reusable bits ------------------------------------------------------
  component PlainLabel: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    elide: Text.ElideRight
  }

  // A square class-wide action: big glyph, short word.
  component ActionTile: Rectangle {
    id: tile
    property string glyph: ""
    property string label: ""
    property bool active: false
    property bool soon: false
    signal clicked()

    radius: Style.cornerRadius
    implicitHeight: Style.space(68)
    color: active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
         : mouse.containsMouse && !soon ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
         : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
    border.width: Style.spacing.hairline
    border.color: active ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
    opacity: soon ? 0.45 : (root.busy ? 0.7 : 1)
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(4)
      PlainLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        text: tile.glyph
        font.pixelSize: Style.font.display
        color: tile.active ? root.accent : root.foreground
      }
      PlainLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        text: tile.soon ? tile.label + " · soon" : tile.label
        font.pixelSize: Style.font.caption
        color: tile.active ? root.accent : root.dim
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: tile.soon ? Qt.ArrowCursor : Qt.PointingHandCursor
      onClicked: if (!tile.soon) tile.clicked()
    }
  }

  // One student: initials in a circle, name below. Click to view their
  // screen, right-click to take control.
  component StudentTile: Item {
    id: student
    required property var modelData
    readonly property bool isOnline: root.status[modelData.host] === true
    // Five to a row, filling the panel, so a full class stays compact.
    width: parent ? (parent.width - parent.spacing * 4) / 5 : Style.space(72)
    height: Style.space(76)
    opacity: isOnline ? 1 : 0.4

    Rectangle {
      id: avatar
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      width: Style.space(46)
      height: width
      radius: width / 2
      color: studentMouse.containsMouse && student.isOnline
        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
        : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      border.width: Style.spacing.hairline
      border.color: root.locked && student.isOnline ? root.urgent
        : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

      PlainLabel {
        anchors.centerIn: parent
        text: root.locked && student.isOnline ? root.iconLock : Model.initials(student.modelData.name)
        font.pixelSize: root.locked && student.isOnline ? Style.font.subtitle : Style.font.body
        font.bold: true
        color: root.locked && student.isOnline ? root.urgent : root.foreground
      }

      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Style.space(11)
        height: width
        radius: width / 2
        color: student.isOnline ? "#4caf50" : root.dim
        border.width: Style.space(2)
        border.color: Color.background
      }
    }

    PlainLabel {
      anchors.top: avatar.bottom
      anchors.topMargin: Style.space(5)
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: student.modelData.name
      font.pixelSize: Style.font.caption
      color: root.dim
    }

    MouseArea {
      id: studentMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: student.isOnline ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: function(event) {
        if (event.button === Qt.RightButton) root.controlStudent(student.modelData)
        else root.viewStudent(student.modelData)
      }
    }
  }

  // ---- Panel ----------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      blocked: composerField.activeFocus
      onCloseRequested: {
        if (root.composer !== "") root.composer = ""
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---- Hero: class name, who's online, switch class ----
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroText.implicitHeight)

          PlainLabel {
            id: heroIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconClass
            font.pixelSize: Style.font.display
          }

          Column {
            id: heroText
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: nextButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            PlainLabel {
              width: parent.width
              text: root.currentClass ? root.currentClass.name : "OmaClass"
              font.pixelSize: Style.font.title
              font.bold: true
            }
            PlainLabel {
              width: parent.width
              text: root.metaText
              color: root.locked ? root.urgent : root.dim
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }

          PanelActionButton {
            id: nextButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.classes.length > 1
            iconText: root.iconNext
            tooltipText: "Next class"
            foreground: root.foreground
            onClicked: root.nextClass()
          }
        }

        // ---- Class-wide actions ----
        Row {
          id: actions
          width: parent.width
          spacing: Style.space(8)
          readonly property real tileWidth: (width - spacing * 3) / 4

          ActionTile {
            width: actions.tileWidth
            glyph: root.locked ? root.iconUnlock : root.iconLock
            label: root.locked ? "Unlock" : "Lock"
            active: root.locked
            onClicked: root.toggleLock()
          }
          ActionTile {
            width: actions.tileWidth
            glyph: root.iconMessage
            label: "Message"
            active: root.composer === "message"
            onClicked: root.openComposer("message")
          }
          ActionTile {
            width: actions.tileWidth
            glyph: root.iconWeb
            label: "Website"
            active: root.composer === "website"
            onClicked: root.openComposer("website")
          }
          ActionTile {
            width: actions.tileWidth
            glyph: root.iconPresent
            label: "Present"
            soon: true
          }
        }

        // ---- Inline composer for Message / Website ----
        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: root.composer !== ""

          TextField {
            id: composerField
            width: parent.width - sendButton.width - parent.spacing
            placeholderText: root.composer === "website" ? "Website address, e.g. code.org" : "Message to the class"
            foreground: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            maximumLength: 500
            onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
            onAccepted: root.submitComposer(text)
            Keys.onEscapePressed: function(event) { root.composer = ""; event.accepted = true }
          }

          Button {
            id: sendButton
            iconText: root.iconSend
            text: root.composer === "website" ? "Open" : "Send"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.submitComposer(composerField.text)
          }
        }

        // ---- One line of feedback ----
        PlainLabel {
          width: parent.width
          visible: root.feedback !== ""
          text: root.feedback
          color: root.dim
          font.pixelSize: Style.font.bodySmall
        }

        PanelSeparator { foreground: root.foreground }

        // ---- Students ----
        PanelSectionHeader {
          foreground: root.foreground
          text: "STUDENTS"
          visible: root.hasClass
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)
          visible: root.hasClass

          Repeater {
            model: root.currentClass ? root.currentClass.computers : []
            delegate: StudentTile {}
          }
        }

        PlainLabel {
          width: parent.width
          visible: !root.hasClass
          wrapMode: Text.WordWrap
          elide: Text.ElideNone
          text: root.hasMastery
            ? "No student computers for this class yet. Set its room in OmaMastery's class.toml, or try the sample class below."
            : "No student computers yet. Add them in the full classroom view, or try the sample class below."
          color: root.dim
          font.pixelSize: Style.font.bodySmall
        }

        PlainLabel {
          width: parent.width
          visible: root.hasClass
          wrapMode: Text.WordWrap
          elide: Text.ElideNone
          text: "Click a student to see their screen · right-click to take control"
          color: root.dim
          font.pixelSize: Style.font.caption
        }

        PanelSeparator { foreground: root.foreground }

        // ---- Footer: full view + sample switch ----
        Item {
          width: parent.width
          implicitHeight: fullButton.implicitHeight

          Button {
            id: fullButton
            anchors.left: parent.left
            iconText: root.iconGrid
            text: "Classroom"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.openFullView()
          }

          Button {
            anchors.left: fullButton.right
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: fullButton.verticalCenter
            visible: root.hasMastery
            iconText: root.iconMastery
            text: "Mastery"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.openMastery()
          }

          Button {
            anchors.right: parent.right
            anchors.verticalCenter: fullButton.verticalCenter
            text: root.sampleMode ? "Sample: on" : "Sample: off"
            selected: root.sampleMode
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            onClicked: root.sampleMode = !root.sampleMode
          }
        }
      }
    }
  }
}
