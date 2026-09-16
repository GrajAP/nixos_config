import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

ScrollView {
  id: timerScroll

  required property var shell
  readonly property bool alarmMode: shell.shutdownTimerMode === "alarm"
  readonly property bool breakMode: shell.shutdownTimerMode === "break"
  readonly property string pendingTarget: breakMode ? shell.breakPendingTarget : (alarmMode ? shell.alarmPendingTarget : shell.shutdownPendingTarget)
  readonly property int pendingRemaining: breakMode ? shell.breakRemaining : (alarmMode ? shell.alarmRemaining : shell.shutdownRemaining)
  readonly property bool ringing: alarmMode && shell.alarmRinging
  readonly property bool active: breakMode ? shell.breakActive : (pendingTarget.length > 0 || ringing)
  readonly property color modeColor: breakMode ? Theme.success : (alarmMode ? Theme.warning : Theme.danger)
  readonly property int sectionLabelHeight: 18

  Layout.fillWidth: true
  Layout.fillHeight: true
  clip: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
  ScrollBar.vertical.policy: ScrollBar.AlwaysOff

  ColumnLayout {
    width: timerScroll.availableWidth
    spacing: 10

    Text {
      Layout.fillWidth: true
      Layout.preferredHeight: timerScroll.sectionLabelHeight
      text: "Timer action"
      color: Theme.muted
      font.family: Theme.fontSans
      font.bold: true
      verticalAlignment: Text.AlignVCenter
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Repeater {
        model: [
          {
            key: "shutdown",
            icon: "\udb81\udc25",
            label: "Shutdown"
          },
          {
            key: "alarm",
            icon: "\udb80\udc20",
            label: "Alarm only"
          },
          {
            key: "break",
            icon: "\udb80\udd76",
            label: "Break timer"
          }
        ]

        delegate: Rectangle {
          required property var modelData

          Layout.fillWidth: true
          implicitHeight: 38
          radius: 9
          color: shell.shutdownTimerMode === modelData.key ? Theme.accent : Theme.surface
          border.color: shell.shutdownTimerMode === modelData.key ? Theme.accent : Theme.border
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: modelData.icon + "  " + modelData.label
            color: shell.shutdownTimerMode === modelData.key ? Theme.background : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: shell.shutdownTimerMode = modelData.key
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.preferredHeight: timerScroll.sectionLabelHeight
      text: timerScroll.breakMode ? "Work session" : (timerScroll.alarmMode ? "Notify in" : "Shutdown in")
      color: Theme.muted
      font.family: Theme.fontSans
      font.bold: true
      verticalAlignment: Text.AlignVCenter
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 78
      radius: 10
      color: Theme.surface

      RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Rectangle {
          Layout.preferredWidth: 40
          Layout.preferredHeight: 40
          radius: 8
          color: Theme.background
          border.color: Theme.border

          Text {
            anchors.centerIn: parent
            text: "−"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 20
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (timerScroll.breakMode)
                shell.setBreakWorkDelay(shell.breakWorkMinutes - 5);
              else
                shell.setShutdownDelay(shell.shutdownDelayMinutes - 5);
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: timerScroll.breakMode ? shell.breakWorkDelayLabel() : shell.shutdownDelayLabel()
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 28
            font.bold: true
          }

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: timerScroll.breakMode
              ? (shell.breakDurationMinutes + "m break after session")
              : (timerScroll.alarmMode ? "notification timer" : "relative timer")
            color: Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: 11
          }
        }

        Rectangle {
          Layout.preferredWidth: 40
          Layout.preferredHeight: 40
          radius: 8
          color: Theme.background
          border.color: Theme.border

          Text {
            anchors.centerIn: parent
            text: "+"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 20
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (timerScroll.breakMode)
                shell.setBreakWorkDelay(shell.breakWorkMinutes + 5);
              else
                shell.setShutdownDelay(shell.shutdownDelayMinutes + 5);
            }
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignLeft
      spacing: 8

      Repeater {
        model: timerScroll.breakMode ? [15, 20, 25, 30, 45, 60] : [15, 30, 60, 120]

        delegate: Rectangle {
          required property int modelData

          Layout.fillWidth: true
          Layout.preferredHeight: 34
          radius: 8
          color: (timerScroll.breakMode ? shell.breakWorkMinutes : shell.shutdownDelayMinutes) === modelData ? Theme.accent : Theme.surface

          Text {
            anchors.centerIn: parent
            text: parent.modelData < 60 ? parent.modelData + "m" : (parent.modelData / 60) + "h"
            color: (timerScroll.breakMode ? shell.breakWorkMinutes : shell.shutdownDelayMinutes) === parent.modelData ? Theme.background : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.bold: (timerScroll.breakMode ? shell.breakWorkMinutes : shell.shutdownDelayMinutes) === parent.modelData
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (timerScroll.breakMode)
                shell.setBreakWorkDelay(parent.modelData);
              else
                shell.setShutdownDelay(parent.modelData);
            }
          }
        }
      }
    }

    Text {
      visible: timerScroll.breakMode
      Layout.fillWidth: true
      Layout.preferredHeight: timerScroll.sectionLabelHeight
      text: "Break duration"
      color: Theme.muted
      font.family: Theme.fontSans
      font.bold: true
      verticalAlignment: Text.AlignVCenter
    }

    RowLayout {
      visible: timerScroll.breakMode
      Layout.fillWidth: true
      spacing: 8

      Repeater {
        model: [3, 5, 10, 15]

        delegate: Rectangle {
          required property int modelData

          Layout.fillWidth: true
          Layout.preferredHeight: 30
          radius: 8
          color: shell.breakDurationMinutes === modelData ? Theme.success : Theme.surface

          Text {
            anchors.centerIn: parent
            text: parent.modelData + "m break"
            color: shell.breakDurationMinutes === parent.modelData ? Theme.background : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.bold: shell.breakDurationMinutes === parent.modelData
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: shell.breakDurationMinutes = parent.modelData
          }
        }
      }
    }

    RowLayout {
      visible: timerScroll.breakMode
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "Auto-repeat cycle"
        color: Theme.muted
        font.family: Theme.fontSans
        font.pixelSize: 12
        font.bold: true
        Layout.fillWidth: true
        verticalAlignment: Text.AlignVCenter
      }

      Rectangle {
        implicitWidth: 40
        implicitHeight: 22
        radius: 11
        color: shell.breakAutoRepeat ? Theme.success : Theme.surface
        border.color: shell.breakAutoRepeat ? Theme.success : Theme.border
        border.width: 1

        Rectangle {
          width: 16
          height: 16
          radius: 8
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: shell.breakAutoRepeat ? undefined : parent.left
          anchors.right: shell.breakAutoRepeat ? parent.right : undefined
          anchors.margins: 3
          color: shell.breakAutoRepeat ? Theme.background : Theme.muted
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: shell.breakAutoRepeat = !shell.breakAutoRepeat
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 32

      Text {
        anchors.fill: parent
        text: {
          if (timerScroll.breakMode)
            return "Reminds you to step away for a " + shell.breakDurationMinutes + "-minute break after " + shell.breakWorkMinutes + " minutes on PC.";
          if (timerScroll.alarmMode)
            return "Alarm rings for about 20 seconds, shows a persistent notification and never powers off the computer.";
          return "Overnight checks still run at 00:00-06:00.";
        }
        color: Theme.muted
        font.family: Theme.fontSans
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 58
      radius: 10
      color: timerScroll.active ? Qt.rgba(timerScroll.modeColor.r, timerScroll.modeColor.g, timerScroll.modeColor.b, 0.16) : Theme.surface
      border.color: timerScroll.active ? timerScroll.modeColor : Theme.border
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        Text {
          Layout.fillWidth: true
          text: {
            if (timerScroll.ringing)
              return "Alarm is ringing";
            if (timerScroll.breakMode) {
              if (shell.breakPhase === "break")
                return "\udb80\udd76 Break time (" + shell.breakDurationMinutes + " min)";
              if (shell.breakPhase === "finished")
                return "\udb80\udd76 Break finished!";
              if (timerScroll.pendingTarget.length > 0)
                return "\udb80\udd76 Work session in progress";
              return "No break timer set";
            }
            if (timerScroll.pendingTarget.length === 0)
              return timerScroll.alarmMode ? "No alarm set" : "No shutdown timer set";
            return (timerScroll.alarmMode ? "Alarm " : "Shutdown ") + timerScroll.pendingTarget;
          }
          color: timerScroll.active ? timerScroll.modeColor : Theme.text
          font.family: Theme.fontSans
          font.bold: true
          font.pixelSize: 13
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: {
            if (timerScroll.ringing)
              return "Confirm below to silence the sound";
            if (timerScroll.breakMode) {
              if (shell.breakPhase === "break")
                return shell.timerRemainingLabel(timerScroll.pendingRemaining) + " left · Step away from screen";
              if (shell.breakPhase === "finished")
                return "Ready to get back to work?";
              if (timerScroll.pendingTarget.length > 0)
                return shell.timerRemainingLabel(timerScroll.pendingRemaining) + " left before break";
              return "Take a " + shell.breakDurationMinutes + "m break every " + shell.breakWorkMinutes + "m of PC work";
            }
            return timerScroll.pendingTarget.length > 0 ? shell.timerRemainingLabel(timerScroll.pendingRemaining) + " left" : "Use the timer above to schedule one";
          }
          color: timerScroll.active ? Theme.text : Theme.muted
          font.family: Theme.fontSans
          font.pixelSize: timerScroll.active ? 13 : 11
          font.bold: timerScroll.active
          elide: Text.ElideRight
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        visible: !timerScroll.ringing && !(timerScroll.breakMode && shell.breakPhase === "finished")
        radius: 9
        color: timerScroll.breakMode ? Theme.success : (timerScroll.alarmMode ? Theme.warning : Theme.surface)

        Text {
          anchors.centerIn: parent
          text: {
            if (timerScroll.breakMode)
              return timerScroll.active ? "\udb80\udd76  Restart break timer" : "\udb80\udd76  Start break timer";
            if (timerScroll.alarmMode)
              return "\udb80\udc20  Set alarm";
            return "\udb81\udc25  Set shutdown";
          }
          color: timerScroll.breakMode || timerScroll.alarmMode ? Theme.background : Theme.text
          font.family: Theme.fontSans
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: shell.scheduleSelectedTimer()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        visible: !timerScroll.ringing && !(timerScroll.breakMode && shell.breakPhase === "finished")
        enabled: timerScroll.active
        opacity: enabled ? 1 : 0.55
        radius: 9
        color: Theme.surface

        Text {
          anchors.centerIn: parent
          text: timerScroll.breakMode && shell.breakPhase === "break" ? "\udb81\udf3a  End break now" : "\udb81\udf3a  Cancel"
          color: Theme.text
          font.family: Theme.fontIcon
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          enabled: timerScroll.active
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: shell.cancelSelectedTimer()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        visible: timerScroll.ringing
        radius: 9
        color: Theme.warning

        Text {
          anchors.centerIn: parent
          text: "✓  Confirm and silence"
          color: Theme.background
          font.family: Theme.fontSans
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: shell.acknowledgeAlarm()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        visible: timerScroll.breakMode && shell.breakPhase === "finished"
        radius: 9
        color: Theme.success

        Text {
          anchors.centerIn: parent
          text: "✓  Start next work session"
          color: Theme.background
          font.family: Theme.fontSans
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: shell.scheduleBreak()
        }
      }
    }
  }
}
