import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs

// Audio settings panel: devices tab for default input/output hardware selection
// and volume, mixer tab for per-application audio stream volume control and routing.
Item {
  id: audioRoot

  required property var shell

  readonly property string activeTab: shell.audioTabMode

  function audioStreams() {
    const streams = Pipewire.nodes.values.filter(node => node && node.audio && node.isStream);
    return streams.sort((a, b) => {
      const aIsOut = (a.properties && a.properties["media.class"] === "Stream/Output/Audio") || a.isSink;
      const bIsOut = (b.properties && b.properties["media.class"] === "Stream/Output/Audio") || b.isSink;
      if (aIsOut && !bIsOut) return -1;
      if (!aIsOut && bIsOut) return 1;
      return streamLabel(a).localeCompare(streamLabel(b));
    });
  }

  function streamLabel(node) {
    if (!node) return "Unknown";
    if (node.properties) {
      if (node.properties["application.name"]) return node.properties["application.name"];
      if (node.properties["media.name"] && node.properties["media.name"] !== "Playback" && node.properties["media.name"] !== "ALSA Playback") return node.properties["media.name"];
      if (node.properties["node.name"]) return node.properties["node.name"];
    }
    return node.description || node.nickname || node.name || "Application";
  }

  function streamDetail(node) {
    if (!node || !node.properties) return "";
    const app = node.properties["application.name"] || "";
    const media = node.properties["media.name"] || "";
    if (media && media !== app && media !== "Playback" && media !== "ALSA Playback") {
      const parts = media.split("/");
      return parts[parts.length - 1];
    }
    return "";
  }

  function streamIcon(node) {
    if (!node || !node.properties) return "audio-speakers";
    const icon = node.properties["application.icon-name"]
      || node.properties["application.process.binary"]
      || node.properties["node.name"]
      || "audio-speakers";
    return Quickshell.iconPath(icon, "audio-speakers");
  }

  function streamIsInput(node) {
    return Boolean(node && node.properties && node.properties["media.class"] === "Stream/Input/Audio");
  }

  function streamTargetDeviceLabel(streamNode) {
    if (!streamNode) return "Default";
    const driverId = Number(streamNode.properties && (streamNode.properties["node.driver-id"] || streamNode.properties["target.node"]));
    if (driverId) {
      const dev = Pipewire.nodes.values.find(n => n.id === driverId);
      if (dev) return shell.audioNodeLabel(dev);
    }
    const defaultDev = streamIsInput(streamNode) ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink;
    return defaultDev ? shell.audioNodeLabel(defaultDev) : "Default";
  }

  function moveStream(streamNode, targetDevice) {
    if (!streamNode || !targetDevice) return;
    const serial = streamNode.properties && streamNode.properties["object.serial"];
    if (!serial) return;
    if (streamIsInput(streamNode)) {
      Quickshell.execDetached(["pactl", "move-source-output", String(serial), String(targetDevice.id)]);
    } else {
      Quickshell.execDetached(["pactl", "move-sink-input", String(serial), String(targetDevice.id)]);
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 14

    // Tab switcher: Devices vs Mixer
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Repeater {
        model: [
          { id: "devices", label: "Devices" },
          { id: "mixer", label: "Mixer" },
        ]

        delegate: Rectangle {
          id: tabButton
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: Theme.radiusSm
          color: audioRoot.activeTab === modelData.id ? Theme.accent : tabMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
          Behavior on color { ColorAnimation { duration: Theme.motionFast } }

          Text {
            anchors.centerIn: parent
            text: tabButton.modelData.label
            color: audioRoot.activeTab === tabButton.modelData.id ? Theme.background : Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 12
            font.bold: audioRoot.activeTab === tabButton.modelData.id
          }

          MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: shell.audioTabMode = tabButton.modelData.id
          }
        }
      }
    }

    // Devices View
    ColumnLayout {
      visible: audioRoot.activeTab === "devices"
      Layout.fillWidth: true
      spacing: 14

      Text { text: "Output device"; color: Theme.muted; font.family: Theme.fontSans; font.bold: true }

      Rectangle {
        id: outputPicker
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.radiusSm
        color: outputMenu.opened ? Theme.surfaceAlt : Theme.surface
        border.color: outputMenu.opened ? Theme.accent : Theme.border
        border.width: 1
        opacity: Pipewire.defaultAudioSink ? 1 : 0.55

        RowLayout {
          anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 9
          Text { text: "󰋋"; color: outputMenu.opened ? Theme.accent : Theme.muted; font.family: Theme.fontIcon; font.pixelSize: 17; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
          Text { text: shell.audioNodeLabel(Pipewire.defaultAudioSink); color: Theme.text; font.family: Theme.font; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
          Text { text: outputMenu.opened ? "⌃" : "⌄"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 16; Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter }
        }

        MouseArea {
          anchors.fill: parent
          enabled: Pipewire.defaultAudioSink || shell.audioSinks().length > 0
          cursorShape: Qt.PointingHandCursor
          onClicked: outputMenu.opened ? outputMenu.close() : outputMenu.open()
        }

        Menu {
          id: outputMenu
          y: outputPicker.height + 4
          width: outputPicker.width
          onOpened: shell.setHoverWidgetMenuOpen(true)
          onClosed: shell.setHoverWidgetMenuOpen(microphoneMenu.opened)
          background: Rectangle {
            color: Theme.background
            border.color: Theme.border
            border.width: 1
            radius: 8
          }

          Repeater {
            model: ScriptModel { values: shell.audioSinks() }

            MenuItem {
              id: outputMenuItem
              required property var modelData
              text: shell.audioNodeLabel(modelData)
              checkable: true
              checked: modelData === Pipewire.defaultAudioSink
              onTriggered: shell.selectAudioSink(modelData)
              implicitHeight: 38
              leftPadding: 12
              rightPadding: 12
              topPadding: 6
              bottomPadding: 6

              indicator: Text {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: outputMenuItem.checked ? "✓" : ""
                color: outputMenuItem.highlighted ? Theme.background : Theme.accent
                font.family: Theme.font
                font.pixelSize: 13
              }

              contentItem: Text {
                leftPadding: outputMenuItem.checkable ? 24 : 0
                rightPadding: 8
                text: outputMenuItem.text
                color: outputMenuItem.highlighted || outputMenuItem.checked ? Theme.background : Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
              }

              background: Rectangle {
                radius: 7
                color: outputMenuItem.highlighted || outputMenuItem.checked ? Theme.accent : "transparent"
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true; spacing: 10
        Text {
          text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? "󰝟" : ""
          color: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? Theme.danger : Theme.accent
          font.family: Theme.fontIcon; font.pixelSize: 22
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted }
        }
        Slider {
          Layout.fillWidth: true; from: 0; to: 1.5
          value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
          onMoved: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = value
        }
        Text {
          text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "0%"
          color: Theme.text
          font.family: Theme.fontMono
          font.pixelSize: 12
          Layout.preferredWidth: 38
          horizontalAlignment: Text.AlignRight
        }
      }

      Text { text: "Microphone input"; color: Theme.muted; font.family: Theme.fontSans; font.bold: true; Layout.topMargin: 4 }

      Rectangle {
        id: microphonePicker
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.radiusSm
        color: microphoneMenu.opened ? Theme.surfaceAlt : Theme.surface
        border.color: microphoneMenu.opened ? Theme.accent : Theme.border
        border.width: 1
        opacity: Pipewire.defaultAudioSource ? 1 : 0.55

        RowLayout {
          anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 9
          Text { text: "󰍬"; color: microphoneMenu.opened ? Theme.accent : Theme.muted; font.family: Theme.fontIcon; font.pixelSize: 17; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
          Text { text: shell.audioNodeLabel(Pipewire.defaultAudioSource); color: Theme.text; font.family: Theme.font; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
          Text { text: microphoneMenu.opened ? "⌃" : "⌄"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 16; Layout.preferredWidth: 18; horizontalAlignment: Text.AlignHCenter }
        }

        MouseArea {
          anchors.fill: parent
          enabled: Pipewire.defaultAudioSource || shell.audioSources().length > 0
          cursorShape: Qt.PointingHandCursor
          onClicked: microphoneMenu.opened ? microphoneMenu.close() : microphoneMenu.open()
        }

        Menu {
          id: microphoneMenu
          y: microphonePicker.height + 4
          width: microphonePicker.width
          onOpened: shell.setHoverWidgetMenuOpen(true)
          onClosed: shell.setHoverWidgetMenuOpen(outputMenu.opened)
          background: Rectangle {
            color: Theme.background
            border.color: Theme.border
            border.width: 1
            radius: 8
          }

          Repeater {
            model: ScriptModel { values: shell.audioSources() }

            MenuItem {
              id: microphoneMenuItem
              required property var modelData
              text: shell.audioNodeLabel(modelData)
              checkable: true
              checked: modelData === Pipewire.defaultAudioSource
              onTriggered: shell.selectAudioSource(modelData)
              implicitHeight: 38
              leftPadding: 12
              rightPadding: 12
              topPadding: 6
              bottomPadding: 6

              indicator: Text {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: microphoneMenuItem.checked ? "✓" : ""
                color: microphoneMenuItem.highlighted ? Theme.background : Theme.accent
                font.family: Theme.font
                font.pixelSize: 13
              }

              contentItem: Text {
                leftPadding: microphoneMenuItem.checkable ? 24 : 0
                rightPadding: 8
                text: microphoneMenuItem.text
                color: microphoneMenuItem.highlighted || microphoneMenuItem.checked ? Theme.background : Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
              }

              background: Rectangle {
                radius: 7
                color: microphoneMenuItem.highlighted || microphoneMenuItem.checked ? Theme.accent : "transparent"
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true; spacing: 10
        Text {
          text: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio && Pipewire.defaultAudioSource.audio.muted ? "󰍭" : "󰍬"
          color: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio && Pipewire.defaultAudioSource.audio.muted ? Theme.danger : Theme.accent
          font.family: Theme.fontIcon; font.pixelSize: 22
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted }
        }
        Slider {
          Layout.fillWidth: true; from: 0; to: 1.5
          value: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.volume : 0
          onMoved: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.volume = value
        }
        Text {
          text: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) + "%" : "0%"
          color: Theme.text
          font.family: Theme.fontMono
          font.pixelSize: 12
          Layout.preferredWidth: 38
          horizontalAlignment: Text.AlignRight
        }
      }
    }

    // Mixer View
    ColumnLayout {
      visible: audioRoot.activeTab === "mixer"
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 12

      // Master Output Volume Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 70
        radius: Theme.radiusSm
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 6

          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
              text: "Master volume"
              color: Theme.muted
              font.family: Theme.fontSans
              font.bold: true
              font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Text {
              text: shell.audioNodeLabel(Pipewire.defaultAudioSink)
              color: Theme.muted
              font.family: Theme.fontSans
              font.pixelSize: 11
              elide: Text.ElideRight
              Layout.maximumWidth: 200
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? "󰝟" : ""
              color: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? Theme.danger : Theme.accent
              font.family: Theme.fontIcon
              font.pixelSize: 20
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
              }
            }

            Slider {
              Layout.fillWidth: true
              from: 0; to: 1.5
              value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
              onMoved: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = value
            }

            Text {
              text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "0%"
              color: Theme.text
              font.family: Theme.fontMono
              font.pixelSize: 12
              Layout.preferredWidth: 38
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }

      // Streams Section Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "Applications"
          color: Theme.muted
          font.family: Theme.fontSans
          font.bold: true
          font.pixelSize: 13
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          radius: 10
          color: Theme.surfaceAlt
          border.color: Theme.border
          border.width: 1
          implicitHeight: 20
          implicitWidth: streamCountText.implicitWidth + 14

          Text {
            id: streamCountText
            anchors.centerIn: parent
            text: audioRoot.audioStreams().length + " active"
            color: Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: 11
          }
        }
      }

      // Streams List or Empty State
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Empty state when no applications are playing audio
        Rectangle {
          visible: audioRoot.audioStreams().length === 0
          anchors.fill: parent
          radius: Theme.radiusSm
          color: Theme.surface
          border.color: Theme.border
          border.width: 1

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
              text: "󰓃"
              color: Theme.muted
              font.family: Theme.fontIcon
              font.pixelSize: 32
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: "No active audio streams"
              color: Theme.text
              font.family: Theme.fontSans
              font.bold: true
              font.pixelSize: 13
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: "Applications playing audio will appear here"
              color: Theme.muted
              font.family: Theme.fontSans
              font.pixelSize: 11
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }

        // Active streams list
        ListView {
          id: streamListView
          visible: audioRoot.audioStreams().length > 0
          anchors.fill: parent
          clip: true
          spacing: 8
          model: ScriptModel { values: audioRoot.audioStreams() }
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: ScrollBar {
            policy: streamListView.contentHeight > streamListView.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
          }

          delegate: Rectangle {
            id: streamCard
            required property var modelData
            readonly property bool isInput: audioRoot.streamIsInput(modelData)
            width: ListView.view.width
            implicitHeight: streamCardLayout.implicitHeight + 16
            radius: Theme.radiusSm
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
              id: streamCardLayout
              anchors.fill: parent
              anchors.margins: 10
              spacing: 8

              // Top row: App icon, Title, Media subtitle, Target sink button
              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                IconImage {
                  implicitSize: 20
                  source: audioRoot.streamIcon(streamCard.modelData)
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    text: audioRoot.streamLabel(streamCard.modelData)
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.bold: true
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    visible: audioRoot.streamDetail(streamCard.modelData).length > 0
                    text: audioRoot.streamDetail(streamCard.modelData)
                    color: Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                // Target Device Selector badge
                Rectangle {
                  id: targetDeviceBadge
                  radius: 6
                  color: targetPickerMenu.opened ? Theme.surfaceAlt : Theme.background
                  border.color: targetPickerMenu.opened ? Theme.accent : Theme.border
                  border.width: 1
                  implicitHeight: 22
                  implicitWidth: targetDeviceRow.implicitWidth + 12

                  RowLayout {
                    id: targetDeviceRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                      text: streamCard.isInput ? "󰍬" : "󰓃"
                      color: Theme.accent
                      font.family: Theme.fontIcon
                      font.pixelSize: 11
                    }

                    Text {
                      text: audioRoot.streamTargetDeviceLabel(streamCard.modelData)
                      color: Theme.text
                      font.family: Theme.fontSans
                      font.pixelSize: 10
                      elide: Text.ElideRight
                      Layout.maximumWidth: 100
                    }

                    Text {
                      text: targetPickerMenu.opened ? "⌃" : "⌄"
                      color: Theme.muted
                      font.family: Theme.font
                      font.pixelSize: 10
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: targetPickerMenu.opened ? targetPickerMenu.close() : targetPickerMenu.open()
                  }

                  Menu {
                    id: targetPickerMenu
                    y: targetDeviceBadge.height + 4
                    x: targetDeviceBadge.width - width
                    width: 250
                    topPadding: 5
                    bottomPadding: 5
                    leftPadding: 5
                    rightPadding: 5
                    onOpened: shell.setHoverWidgetMenuOpen(true)
                    onClosed: shell.setHoverWidgetMenuOpen(false)

                    background: Rectangle {
                      color: Theme.background
                      border.color: Theme.border
                      border.width: 1
                      radius: 8
                    }

                    Repeater {
                      model: ScriptModel { values: streamCard.isInput ? shell.audioSources() : shell.audioSinks() }

                      MenuItem {
                        id: targetMenuItem
                        required property var modelData
                        text: shell.audioNodeLabel(modelData)
                        checkable: true
                        checked: {
                          const driverId = Number(streamCard.modelData.properties && (streamCard.modelData.properties["node.driver-id"] || streamCard.modelData.properties["target.node"]));
                          if (driverId) return driverId === targetMenuItem.modelData.id;
                          const defaultDev = streamCard.isInput ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink;
                          return targetMenuItem.modelData === defaultDev;
                        }
                        onTriggered: audioRoot.moveStream(streamCard.modelData, targetMenuItem.modelData)
                        implicitHeight: 38
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 6
                        bottomPadding: 6

                        indicator: Text {
                          x: 12
                          anchors.verticalCenter: parent.verticalCenter
                          text: targetMenuItem.checked ? "✓" : ""
                          color: targetMenuItem.highlighted ? Theme.background : Theme.accent
                          font.family: Theme.font
                          font.pixelSize: 13
                        }

                        contentItem: Text {
                          leftPadding: targetMenuItem.checkable ? 24 : 0
                          rightPadding: 8
                          text: targetMenuItem.text
                          color: targetMenuItem.highlighted || targetMenuItem.checked ? Theme.background : Theme.text
                          font.family: Theme.font
                          font.pixelSize: 13
                          elide: Text.ElideRight
                          verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                          radius: 7
                          color: targetMenuItem.highlighted || targetMenuItem.checked ? Theme.accent : "transparent"
                        }
                      }
                    }
                  }
                }
              }

              // Bottom row: Mute button, Slider, Percentage
              RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                  text: {
                    if (streamCard.isInput) {
                      return streamCard.modelData.audio && streamCard.modelData.audio.muted ? "󰍭" : "󰍬";
                    }
                    return streamCard.modelData.audio && streamCard.modelData.audio.muted ? "󰝟" : "";
                  }
                  color: streamCard.modelData.audio && streamCard.modelData.audio.muted ? Theme.danger : Theme.accent
                  font.family: Theme.fontIcon
                  font.pixelSize: 20
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (streamCard.modelData.audio) streamCard.modelData.audio.muted = !streamCard.modelData.audio.muted
                  }
                }

                Slider {
                  Layout.fillWidth: true
                  from: 0
                  to: 1.5
                  value: streamCard.modelData.audio ? streamCard.modelData.audio.volume : 0
                  onMoved: if (streamCard.modelData.audio) streamCard.modelData.audio.volume = value
                }

                Text {
                  text: streamCard.modelData.audio ? Math.round(streamCard.modelData.audio.volume * 100) + "%" : "0%"
                  color: Theme.text
                  font.family: Theme.fontMono
                  font.pixelSize: 12
                  Layout.preferredWidth: 38
                  horizontalAlignment: Text.AlignRight
                }
              }
            }
          }
        }
      }
    }
  }
}
