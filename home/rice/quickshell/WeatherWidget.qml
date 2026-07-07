import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs

ColumnLayout {
  required property var shell

  Layout.fillWidth: true
  Layout.fillHeight: true
  spacing: 10
  clip: true

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 118
    radius: 12
    color: Theme.surfaceAlt
    border.color: Theme.border
    border.width: 1
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 14

      Text {
        text: shell.weatherData ? shell.weatherGlyph() : "󰖙"
        color: shell.weatherData ? Theme.accent : Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: 52
        Layout.preferredWidth: 58
        horizontalAlignment: Text.AlignHCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
          text: shell.weatherData && shell.weatherData.temperature !== null && shell.weatherData.temperature !== undefined ? Math.round(shell.weatherData.temperature) + "°" : (shell.weatherLoading ? "Loading" : "No data")
          color: Theme.text
          font.family: Theme.fontSans
          font.pixelSize: 36
          font.bold: true
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: shell.weatherData ? shell.weatherData.description : (shell.weatherError || "Warsaw forecast")
          color: shell.weatherError ? Theme.danger : shell.secondaryText
          font.family: Theme.fontSans
          font.pixelSize: 13
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: shell.weatherData && shell.weatherLastUpdated ? "Updated " + shell.weatherLastUpdated : "Open-Meteo"
          color: shell.secondaryText
          font.family: Theme.fontSans
          font.pixelSize: 11
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      Rectangle {
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: 8
        color: Theme.surface

        Text {
          anchors.centerIn: parent
          text: "󰑐"
          color: Theme.text
          font.family: Theme.fontIcon
          font.pixelSize: 15
        }

        RotationAnimation on rotation {
          running: shell.weatherLoading
          loops: Animation.Infinite
          from: 0
          to: 360
          duration: 900
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: shell.refreshWeather()
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 6

    Repeater {
      model: [
        { id: "current", label: "Now" },
        { id: "future", label: "Daily" },
        { id: "hourly", label: "Hourly" },
      ]

      delegate: Rectangle {
        id: weatherTab
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 8
        color: shell.weatherForecastMode === modelData.id ? Theme.accent : Theme.surface

        Text {
          anchors.centerIn: parent
          text: modelData.label
          color: shell.weatherForecastMode === modelData.id ? Theme.background : Theme.text
          font.family: Theme.fontSans
          font.pixelSize: 12
          font.bold: shell.weatherForecastMode === modelData.id
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: shell.weatherForecastMode = modelData.id
        }
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true

    GridLayout {
      visible: shell.weatherForecastMode === "current"
      anchors.fill: parent
      columns: 2
      rowSpacing: 8
      columnSpacing: 8

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        radius: Theme.radiusMd
        color: Theme.surface
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 2
          Text { text: "Feels like"; color: shell.secondaryText; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: shell.weatherData && shell.weatherData.apparentTemperature !== null && shell.weatherData.apparentTemperature !== undefined ? Math.round(shell.weatherData.apparentTemperature) + "°C" : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        radius: Theme.radiusMd
        color: Theme.surface
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 2
          Text { text: "Wind"; color: shell.secondaryText; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: shell.weatherData && shell.weatherData.windSpeed !== null && shell.weatherData.windSpeed !== undefined ? Math.round(shell.weatherData.windSpeed) + " km/h" : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        radius: Theme.radiusMd
        color: Theme.surface
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 2
          Text { text: "Low"; color: shell.secondaryText; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: shell.weatherData && shell.weatherData.todayMin !== null && shell.weatherData.todayMin !== undefined ? Math.round(shell.weatherData.todayMin) + "°" : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        radius: Theme.radiusMd
        color: Theme.surface
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 2
          Text { text: "High"; color: shell.secondaryText; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: shell.weatherData && shell.weatherData.todayMax !== null && shell.weatherData.todayMax !== undefined ? Math.round(shell.weatherData.todayMax) + "°" : "—"; color: Theme.text; font.family: Theme.font; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
        }
      }

      Text {
        visible: shell.weatherError.length > 0
        Layout.columnSpan: 2
        Layout.fillWidth: true
        text: shell.weatherError
        color: Theme.danger
        font.family: Theme.fontSans
        font.pixelSize: 11
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }
    }

    ListView {
      visible: shell.weatherForecastMode === "future"
      anchors.fill: parent
      clip: true
      spacing: 7
      model: shell.weatherData && shell.weatherData.dailyForecast ? shell.weatherData.dailyForecast : []

      delegate: Rectangle {
        required property var modelData
        readonly property bool isToday: shell.weatherIsToday(modelData.date)
        width: ListView.view.width
        height: 44
        radius: 10
        color: isToday ? Theme.accent : Theme.surface

        RowLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10
          Text { text: parent.parent.isToday ? "Today" : shell.weatherShortDate(parent.parent.modelData.date); color: parent.parent.isToday ? Theme.background : Theme.text; font.family: Theme.font; font.bold: parent.parent.isToday; Layout.preferredWidth: 50 }
          Text { text: shell.weatherGlyphForCode(parent.parent.modelData.weatherCode); color: parent.parent.isToday ? Theme.background : Theme.accent; font.family: Theme.font; font.pixelSize: 17; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignHCenter }
          Item { Layout.fillWidth: true }
          Text { text: parent.parent.modelData.minTemperature !== null && parent.parent.modelData.minTemperature !== undefined && parent.parent.modelData.maxTemperature !== null && parent.parent.modelData.maxTemperature !== undefined ? Math.round(parent.parent.modelData.minTemperature) + "°  " + Math.round(parent.parent.modelData.maxTemperature) + "°" : "—"; color: parent.parent.isToday ? Theme.background : Theme.text; font.family: Theme.fontSans; font.bold: true; Layout.preferredWidth: 74; horizontalAlignment: Text.AlignRight }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: parent.count === 0
        text: shell.weatherLoading ? "Loading forecast…" : (shell.weatherError || "No forecast available")
        color: shell.weatherError ? Theme.danger : Theme.muted
        font.family: Theme.fontSans
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - 24
        wrapMode: Text.Wrap
      }
    }

    ListView {
      visible: shell.weatherForecastMode === "hourly"
      anchors.fill: parent
      clip: true
      spacing: 7
      model: shell.weatherData && shell.weatherData.hourlyForecast ? shell.weatherData.hourlyForecast.slice(0, 12) : []

      delegate: Rectangle {
        required property var modelData
        readonly property bool isCurrentHour: shell.weatherIsCurrentHour(modelData.time)
        width: ListView.view.width
        height: 44
        radius: 10
        color: isCurrentHour ? Theme.accent : Theme.surface
        border.color: isCurrentHour ? Theme.accent : Theme.border
        border.width: isCurrentHour ? 0 : 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10
          Text { text: parent.parent.isCurrentHour ? "Now" : shell.weatherHourLabel(parent.parent.modelData.time); color: parent.parent.isCurrentHour ? Theme.background : Theme.text; font.family: Theme.font; font.bold: parent.parent.isCurrentHour; Layout.preferredWidth: 46 }
          Text { text: shell.weatherGlyphForCode(parent.parent.modelData.weatherCode); color: parent.parent.isCurrentHour ? Theme.background : shell.secondaryText; font.family: Theme.font; font.pixelSize: 17; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignHCenter }
          Text { text: parent.parent.modelData.temperature !== null && parent.parent.modelData.temperature !== undefined ? Math.round(parent.parent.modelData.temperature) + "°C" : "—"; color: parent.parent.isCurrentHour ? Theme.background : Theme.text; font.family: Theme.fontSans; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
          Text { text: parent.parent.modelData.windSpeed !== null && parent.parent.modelData.windSpeed !== undefined ? Math.round(parent.parent.modelData.windSpeed) + " km/h" : "—"; color: parent.parent.isCurrentHour ? Theme.background : shell.secondaryText; font.family: Theme.font; font.pixelSize: 11; Layout.preferredWidth: 88; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: parent.count === 0
        text: shell.weatherLoading ? "Loading forecast…" : (shell.weatherError || "No hourly forecast")
        color: shell.weatherError ? Theme.danger : Theme.muted
        font.family: Theme.fontSans
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        width: parent.width - 24
        wrapMode: Text.Wrap
      }
    }
  }
}
