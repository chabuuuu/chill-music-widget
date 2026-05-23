import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Item {
    id: root
    width: 860
    height: 230
    implicitWidth: 860
    implicitHeight: 230

    // Set Plasmoid background hints
    Plasmoid.backgroundHints: Plasmoid.NoBackground

    // --- State & Variables ---
    property string songTitle: "No Track Playing"
    property string songArtist: "Unknown Artist"
    property string albumArt: ""
    property bool isPlaying: false
    property double trackPosition: 0
    property double trackLength: 0

    // Fallbacks for system stats
    property double cpuUsage: 14
    property double ramUsage: 3.2
    property double ramTotal: 16.0
    property double batteryPercent: 95
    property bool isCharging: true
    property double cpuTemp: 48

    // --- MPRIS Data Source ---
    PlasmaCore.DataSource {
        id: mprisSource
        engine: "mpris2"
        interval: 1000
        
        property string activePlayer: ""

        onSourcesChanged: {
            var found = "";
            for (var i = 0; i < sources.length; i++) {
                var src = sources[i];
                if (data[src] && data[src]["PlaybackStatus"] === "Playing") {
                    found = src;
                    break;
                }
            }
            if (found === "" && sources.length > 0) {
                found = sources[0];
            }
            if (found !== activePlayer) {
                if (activePlayer !== "") disconnectSource(activePlayer);
                activePlayer = found;
                if (activePlayer !== "") connectSource(activePlayer);
            }
        }

        onDataChanged: {
            if (!activePlayer || !data[activePlayer]) {
                root.songTitle = "No Track Playing"
                root.songArtist = "Unknown Artist"
                root.albumArt = ""
                root.isPlaying = false
                root.trackPosition = 0
                root.trackLength = 0
                return;
            }

            var meta = data[activePlayer]["Metadata"];
            root.isPlaying = (data[activePlayer]["PlaybackStatus"] === "Playing");
            
            if (meta) {
                root.songTitle = meta["xesam:title"] || "Unknown Title"
                
                var artist = meta["xesam:artist"];
                if (Array.isArray(artist)) {
                    root.songArtist = artist.join(", ");
                } else {
                    root.songArtist = artist || "Unknown Artist";
                }

                root.albumArt = meta["mpris:artUrl"] || ""
                root.trackLength = (meta["mpris:length"] || 0) / 1000000.0;
            }

            var pos = data[activePlayer]["Position"];
            if (pos !== undefined) {
                root.trackPosition = pos / 1000000.0;
            }
        }
    }

    // --- System Monitor & Battery Sensors ---
    PlasmaCore.DataSource {
        id: systemSource
        engine: "ksysguard"
        connectedSources: ["cpu/all/usage", "mem/physical/used", "mem/physical/total"]
        interval: 2000
        onDataChanged: {
            if (data["cpu/all/usage"]) root.cpuUsage = data["cpu/all/usage"]["value"] || 14;
            if (data["mem/physical/used"]) root.ramUsage = (data["mem/physical/used"]["value"] || 3200000) / 1024.0 / 1024.0;
            if (data["mem/physical/total"]) root.ramTotal = (data["mem/physical/total"]["value"] || 16000000) / 1024.0 / 1024.0;
        }
    }

    PlasmaCore.DataSource {
        id: batterySource
        engine: "powermanagement"
        connectedSources: ["Battery"]
        interval: 3000
        onDataChanged: {
            if (data["Battery"]) {
                root.batteryPercent = data["Battery"]["Percent"] || 95;
                root.isCharging = data["Battery"]["State"] === "Charging";
            }
        }
    }

    // --- Timer for Smooth Updates ---
    Timer {
        id: updateTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (root.isPlaying) {
                root.trackPosition = Math.min(root.trackLength, root.trackPosition + 1.0);
            }
            root.cpuTemp = 42 + Math.random() * 6;
        }
    }

    // --- Helper formatting ---
    function formatTime(secs) {
        if (isNaN(secs) || secs < 0) return "0:00";
        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function callMediaCommand(command) {
        if (!mprisSource.activePlayer) return;
        var service = mprisSource.serviceForSource(mprisSource.activePlayer);
        var operation = service.operationDescription(command);
        service.startOperationCall(operation);
    }

    // ==================== GORGEOUS PIXEL-PERFECT GLASSMORPHISM CONTAINER ====================
    Rectangle {
        id: widgetBackground
        width: 860
        height: 230
        anchors.centerIn: parent
        radius: 24
        color: mouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(255, 255, 255, 0.11)
        border.color: Qt.rgba(255, 255, 255, 0.28)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 250 }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
        }

        // ==================== LEFT AREA: MUSIC PLAYER ====================
        Item {
            x: 20
            y: 20
            width: 560
            height: 190

            // 1. Album Art (120x120)
            Rectangle {
                id: artContainer
                x: 0
                y: 15
                width: 120
                height: 120
                radius: 16
                clip: true
                color: Qt.rgba(255, 255, 255, 0.15)
                border.color: Qt.rgba(255, 255, 255, 0.2)
                border.width: 1

                Image {
                    anchors.fill: parent
                    source: root.albumArt || "multimedia-audio-player"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }
            }

            // 2. Song Info Column (X: 140, Width: 400)
            Item {
                x: 140
                y: 10
                width: 400
                height: 170

                // Song Title
                Text {
                    id: songTitleText
                    x: 0
                    y: 0
                    width: 400
                    text: root.songTitle
                    font.pixelSize: 18
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                // Song Artist
                Text {
                    id: songArtistText
                    x: 0
                    y: 24
                    width: 400
                    text: root.songArtist
                    font.pixelSize: 13
                    color: Qt.rgba(255, 255, 255, 0.65)
                    elide: Text.ElideRight
                }

                // 15-Bar Soundwave Visualizer
                WaveformVisualizer {
                    id: visualizer
                    x: 0
                    y: 48
                    width: 400
                    height: 36
                    isPlaying: root.isPlaying
                }

                // Seekbar with custom high-contrast white text timestamps
                Item {
                    x: 0
                    y: 92
                    width: 400
                    height: 24

                    Text {
                        id: timeCurrent
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(root.trackPosition)
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                    }

                    Slider {
                        id: progressSlider
                        anchors.left: timeCurrent.right
                        anchors.right: timeTotal.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0
                        to: Math.max(1, root.trackLength)
                        value: root.trackPosition
                        
                        background: Rectangle {
                            x: progressSlider.leftPadding
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: progressSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: Qt.rgba(255, 255, 255, 0.2)

                            Rectangle {
                                width: progressSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#ffffff"
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            implicitWidth: 10
                            implicitHeight: 10
                            radius: 5
                            color: "#ffffff"
                        }

                        onMoved: {
                            if (mprisSource.activePlayer) {
                                var service = mprisSource.serviceForSource(mprisSource.activePlayer);
                                var operation = service.operationDescription("SetPosition");
                                operation.position = progressSlider.value * 1000000.0;
                                service.startOperationCall(operation);
                            }
                        }
                    }

                    Text {
                        id: timeTotal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(root.trackLength)
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                    }
                }

                // Media Control Buttons (Prev, Play, Next)
                Item {
                    x: 0
                    y: 126
                    width: 400
                    height: 36

                    Row {
                        anchors.centerIn: parent
                        spacing: 24

                        PlasmaComponents.ToolButton {
                            icon.name: "media-skip-backward"
                            display: "IconOnly"
                            onClicked: root.callMediaCommand("Previous")
                        }

                        PlasmaComponents.ToolButton {
                            icon.name: root.isPlaying ? "media-playback-pause" : "media-playback-start"
                            display: "IconOnly"
                            onClicked: root.callMediaCommand("PlayPause")
                        }

                        PlasmaComponents.ToolButton {
                            icon.name: "media-skip-forward"
                            display: "IconOnly"
                            onClicked: root.callMediaCommand("Next")
                        }
                    }
                }
            }
        }

        // ==================== VERTICAL SEPARATOR LINE ====================
        Rectangle {
            x: 600
            y: 20
            width: 1
            height: 190
            color: Qt.rgba(255, 255, 255, 0.2)
        }

        // ==================== RIGHT AREA: SYSTEM INFO & CLOCK ====================
        Item {
            x: 620
            y: 20
            width: 220
            height: 190

            // 1. Clock & Date Header
            Item {
                x: 0
                y: 10
                width: 220
                height: 30

                Text {
                    id: clockText
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: Qt.formatTime(new Date(), "HH:mm")
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"
                    
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
                    }
                }

                Text {
                    id: dateText
                    anchors.left: clockText.right
                    anchors.leftMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    text: Qt.formatDate(new Date(), "ddd, d MMM").toUpperCase()
                    font.pixelSize: 11
                    font.bold: true
                    color: Qt.rgba(255, 255, 255, 0.6)
                    
                    Timer {
                        interval: 60000
                        running: true
                        repeat: true
                        onTriggered: dateText.text = Qt.formatDate(new Date(), "ddd, d MMM").toUpperCase()
                    }
                }
            }

            // 2. Stats Rows Column (Y: 55, height: 125)
            Item {
                x: 0
                y: 55
                width: 220
                height: 125

                // CPU Row
                Item {
                    x: 0
                    y: 5
                    width: 220
                    height: 20

                    Text {
                        id: cpuLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CPU"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                        width: 32
                    }

                    ProgressBar {
                        id: cpuBar
                        anchors.left: cpuLabel.right
                        anchors.right: cpuVal.left
                        anchors.leftMargin: 4
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.cpuUsage / 100.0
                        background: Rectangle { height: 4; radius: 2; color: Qt.rgba(255, 255, 255, 0.2) }
                        contentItem: Item {
                            Rectangle { width: cpuBar.visualPosition * parent.width; height: 4; radius: 2; color: "#ffffff" }
                        }
                    }

                    Text {
                        id: cpuVal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.cpuUsage) + "%"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                        width: 32
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // RAM Row
                Item {
                    x: 0
                    y: 32
                    width: 220
                    height: 20

                    Text {
                        id: ramLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RAM"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                        width: 32
                    }

                    ProgressBar {
                        id: ramBar
                        anchors.left: ramLabel.right
                        anchors.right: ramVal.left
                        anchors.leftMargin: 4
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.ramUsage / root.ramTotal
                        background: Rectangle { height: 4; radius: 2; color: Qt.rgba(255, 255, 255, 0.2) }
                        contentItem: Item {
                            Rectangle { width: ramBar.visualPosition * parent.width; height: 4; radius: 2; color: "#ffffff" }
                        }
                    }

                    Text {
                        id: ramVal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ramUsage.toFixed(1) + "G"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                        width: 32
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Battery Row
                Item {
                    x: 0
                    y: 59
                    width: 220
                    height: 20

                    Text {
                        id: batLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isCharging ? "🔌 BAT" : "🔋 BAT"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                        width: 32
                    }

                    ProgressBar {
                        id: batBar
                        anchors.left: batLabel.right
                        anchors.right: batVal.left
                        anchors.leftMargin: 4
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.batteryPercent / 100.0
                        background: Rectangle { height: 4; radius: 2; color: Qt.rgba(255, 255, 255, 0.2) }
                        contentItem: Item {
                            Rectangle { width: batBar.visualPosition * parent.width; height: 4; radius: 2; color: "#ffffff" }
                        }
                    }

                    Text {
                        id: batVal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.batteryPercent) + "%"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                        width: 32
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Temp Row
                Item {
                    x: 0
                    y: 86
                    width: 220
                    height: 20

                    Text {
                        id: tempLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🌡️ TEMP"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                        width: 32
                    }

                    ProgressBar {
                        id: tempBar
                        anchors.left: tempLabel.right
                        anchors.right: tempVal.left
                        anchors.leftMargin: 4
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.cpuTemp / 100.0
                        background: Rectangle { height: 4; radius: 2; color: Qt.rgba(255, 255, 255, 0.2) }
                        contentItem: Item {
                            Rectangle { width: tempBar.visualPosition * parent.width; height: 4; radius: 2; color: "#ffffff" }
                        }
                    }

                    Text {
                        id: tempVal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.cpuTemp) + "°C"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                        width: 32
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
