import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

ScrollView {
  id: timerScroll

  required property var shell
  readonly property bool alarmMode: shell.shutdownTimerMode === "alarm"
  readonly property string pendingTarget: alarmMode ? shell.alarmPendingTarget : shell.shutdownPendingTarget
  readonly property int pendingRemaining: alarmMode ? shell.alarmRemaining : shell.shutdownRemaining
  readonly property bool ringing: alarmMode && shell.alarmRinging
  readonly property bool active: pendingTarget.length > 0 || ringing
  readonly property color modeColor: alarmMode ? Theme.warning : Theme.danger
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
            icon: "󰐥",
            label: "Shutdown"
          },
          {
            key: "alarm",
            icon: "󰀠",
            label: "Alarm only"
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
      text: timerScroll.alarmMode ? "Notify in" : "Shutdown in"
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
            onClicked: shell.setShutdownDelay(shell.shutdownDelayMinutes - 5)
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: shell.shutdownDelayLabel()
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 28
            font.bold: true
          }

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: timerScroll.alarmMode ? "notification timer" : "relative timer"
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
            onClicked: shell.setShutdownDelay(shell.shutdownDelayMinutes + 5)
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignLeft
      spacing: 8

      Repeater {
        model: [15, 30, 60, 120]

        delegate: Rectangle {
          required property int modelData

          Layout.fillWidth: true
          Layout.preferredHeight: 34
          radius: 8
          color: shell.shutdownDelayMinutes === modelData ? Theme.accent : Theme.surface

          Text {
            anchors.centerIn: parent
            text: parent.modelData < 60 ? parent.modelData + "m" : (parent.modelData / 60) + "h"
            color: shell.shutdownDelayMinutes === parent.modelData ? Theme.background : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.bold: shell.shutdownDelayMinutes === parent.modelData
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: shell.setShutdownDelay(parent.modelData)
          }
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 32

      Text {
        anchors.fill: parent
        text: timerScroll.alarmMode ? "Alarm rings for about 20 seconds, shows a persistent notification and never powers off the computer." : "Overnight checks still run at 00:00-06:00."
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
          text: timerScroll.ringing
            ? "Confirm below to silence the sound"
            : (timerScroll.pendingTarget.length > 0 ? shell.timerRemainingLabel(timerScroll.pendingRemaining) + " left" : "Use the timer above to schedule one")
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
        visible: !timerScroll.ringing
        radius: 9
        color: timerScroll.alarmMode ? Theme.warning : Theme.surface

        Text {
          anchors.centerIn: parent
          text: timerScroll.alarmMode ? "󰀠  Set alarm" : "󰐥  Set shutdown"
          color: timerScroll.alarmMode ? Theme.background : Theme.text
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
        visible: !timerScroll.ringing
        enabled: timerScroll.pendingTarget.length > 0
        opacity: enabled ? 1 : 0.55
        radius: 9
        color: Theme.surface

        Text {
          anchors.centerIn: parent
          text: "󰜺  Cancel"
          color: Theme.text
          font.family: Theme.fontIcon
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          enabled: timerScroll.pendingTarget.length > 0
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
    }
  }
}
