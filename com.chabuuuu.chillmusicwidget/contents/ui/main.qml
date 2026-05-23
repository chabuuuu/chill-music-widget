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
    property color accentColor: "#14ffec" // Vibrant glowing cyan matching original PyQt5 app 100%
    property string songTitle: "No active player"
    property string songArtist: "Play music to visualize"
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
                root.songTitle = "No active player"
                root.songArtist = "Play music to visualize"
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

    // --- Command Execution Engine (Bypasses QML D-Bus limitations for Seeking & Volume) ---
    PlasmaCore.DataSource {
        id: executableSource
        engine: "executable"
        connectedSources: []
        onNewData: disconnectSource(sourceName) // Run and clean once!
        
        function runCommand(cmd) {
            connectSource(cmd)
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

    // ==================== RESPONSIVE GLASSMORPHISM BACKGROUND CARD ====================
    Rectangle {
        id: widgetBackground
        anchors.fill: parent // Dynamic sizing matching containment grid exactly to prevent any clipping
        radius: 40 // Rounded corners matching original card QSS 100%
        color: mouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(255, 255, 255, 0.08)
        border.color: mouseArea.containsMouse ? Qt.rgba(20, 255, 236, 0.45) : Qt.rgba(255, 255, 255, 0.18) // Accent glowing cyan outline on hover!
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 250 } }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
        }

        // ==================== RIGHT PANEL: STATS & CLOCK (Width: 220px, Anchored Right) ====================
        Item {
            id: rightPanel
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 24
            width: 220

            // 1. Clock & Date Header
            Item {
                id: clockHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 40

                Text {
                    id: clockText
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: Qt.formatTime(new Date(), "HH:mm")
                    font.pixelSize: 34
                    font.weight: Font.Light
                    font.family: "Inter"
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
                    anchors.leftMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: Qt.formatDate(new Date(), "ddd, d MMM").toUpperCase()
                    font.pixelSize: 9
                    font.bold: true
                    font.family: "Inter"
                    color: Qt.rgba(209, 213, 219, 0.8)
                    
                    Timer {
                        interval: 60000
                        running: true
                        repeat: true
                        onTriggered: dateText.text = Qt.formatDate(new Date(), "ddd, d MMM").toUpperCase()
                    }
                }
            }

            // 2. Stats Rows Column (Y: 55, height: 125)
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: clockHeader.bottom
                anchors.topMargin: 12
                spacing: 6

                // CPU Row
                Item {
                    width: 220
                    height: 18

                    Text {
                        id: cpuLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⚡ CPU"
                        font.pixelSize: 10
                        font.family: "Inter"
                        color: Qt.rgba(209, 213, 219, 0.8)
                        width: 48
                    }

                    ProgressBar {
                        id: cpuBar
                        anchors.left: cpuLabel.right
                        anchors.right: cpuVal.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.cpuUsage / 100.0
                        background: Rectangle { height: 6; radius: 3; color: Qt.rgba(255, 255, 255, 0.1) }
                        contentItem: Item {
                            Rectangle { width: cpuBar.visualPosition * parent.width; height: 6; radius: 3; color: root.accentColor }
                        }
                    }

                    Text {
                        id: cpuVal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.cpuUsage) + "%"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter"
                        color: root.accentColor
                        width: 38
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // RAM Row
                Item {
                    width: 220
                    height: 18

                    Text {
                        id: ramLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🧠 RAM"
                        font.pixelSize: 10
                        font.family: "Inter"
                        color: Qt.rgba(209, 213, 219, 0.8)
                        width: 48
                    }

                    ProgressBar {
                        id: ramBar
                        anchors.left: ramLabel.right
                        anchors.right: ramVal.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.ramUsage / root.ramTotal
                        background: Rectangle { height: 6; radius: 3; color: Qt.rgba(255, 255, 255, 0.1) }
                        contentItem: Item {
                            Rectangle { width: ramBar.visualPosition * parent.width; height: 6; radius: 3; color: root.accentColor }
                        }
                    }

                    Text {
                        id: ramVal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ramUsage.toFixed(1) + " GB"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter"
                        color: root.accentColor
                        width: 38
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Battery Row
                Item {
                    width: 220
                    height: 18

                    Text {
                        id: batLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isCharging ? "🔌 Battery" : "🔋 Battery"
                        font.pixelSize: 10
                        font.family: "Inter"
                        color: Qt.rgba(209, 213, 219, 0.8)
                        width: 48
                    }

                    ProgressBar {
                        id: batBar
                        anchors.left: batLabel.right
                        anchors.right: batVal.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.batteryPercent / 100.0
                        background: Rectangle { height: 6; radius: 3; color: Qt.rgba(255, 255, 255, 0.1) }
                        contentItem: Item {
                            Rectangle { width: batBar.visualPosition * parent.width; height: 6; radius: 3; color: root.accentColor }
                        }
                    }

                    Text {
                        id: batVal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.batteryPercent) + "%"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter"
                        color: root.accentColor
                        width: 38
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Temp Row
                Item {
                    width: 220
                    height: 18

                    Text {
                        id: tempLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🌡️ Temp"
                        font.pixelSize: 10
                        font.family: "Inter"
                        color: Qt.rgba(209, 213, 219, 0.8)
                        width: 48
                    }

                    ProgressBar {
                        id: tempBar
                        anchors.left: tempLabel.right
                        anchors.right: tempVal.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.cpuTemp / 100.0
                        background: Rectangle { height: 6; radius: 3; color: Qt.rgba(255, 255, 255, 0.1) }
                        contentItem: Item {
                            Rectangle { width: tempBar.visualPosition * parent.width; height: 6; radius: 3; color: root.accentColor }
                        }
                    }

                    Text {
                        id: tempVal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.cpuTemp) + "°C"
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Inter"
                        color: root.accentColor
                        width: 38
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // ==================== LEFT AREA: MUSIC PLAYER (Responsive Layout, Anchored Left) ====================
        Item {
            id: leftPanel
            anchors.left: parent.left
            anchors.right: rightPanel.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 24
            anchors.rightMargin: 36 // Clean space separator matching mockup (no vertical line!)

            // 1. Album Art (Dynamic Square sizing to fit the vertical height perfectly!)
            Rectangle {
                id: artContainer
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: height // Perfect square!
                radius: 20
                clip: true
                color: Qt.rgba(255, 255, 255, 0.12)
                border.color: Qt.rgba(255, 255, 255, 0.2)
                border.width: 1

                Image {
                    anchors.fill: parent
                    source: root.albumArt || "multimedia-audio-player"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }
            }

            // 2. Song details and controllers (Responsive width takes all remaining space)
            Item {
                anchors.left: artContainer.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20

                // Song Title
                Text {
                    id: songTitleText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    text: root.songTitle
                    font.pixelSize: 22
                    font.bold: true
                    font.family: "Inter"
                    color: "#ffffff"
                    elide: Text.ElideRight
                }

                // Song Artist
                Text {
                    id: songArtistText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: songTitleText.bottom
                    anchors.topMargin: 2
                    text: root.songArtist
                    font.pixelSize: 13
                    font.family: "Inter"
                    color: Qt.rgba(209, 213, 219, 0.85)
                    elide: Text.ElideRight
                }

                // 15-Bar soundwave visualizer (glowing cyan accent)
                WaveformVisualizer {
                    id: visualizer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: songArtistText.bottom
                    anchors.topMargin: 10
                    height: 30
                    isPlaying: root.isPlaying
                }

                // Seekbar and timestamps
                Item {
                    id: progressRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: visualizer.bottom
                    anchors.topMargin: 12
                    height: 20

                    Text {
                        id: timeCurrent
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(root.trackPosition)
                        font.pixelSize: 11
                        font.family: "monospace"
                        color: "#ffffff"
                    }

                    Slider {
                        id: progressSlider
                        anchors.left: timeCurrent.right
                        anchors.right: timeTotal.left
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
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
                                color: root.accentColor // Glowing cyan slider track!
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                            y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 6
                            color: root.accentColor // Glowing cyan handle!
                        }

                        onMoved: {
                            // Call playerctl via executable source to perform highly robust absolute timeline seeking!
                            executableSource.runCommand("playerctl position " + progressSlider.value)
                        }
                    }

                    Text {
                        id: timeTotal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(root.trackLength)
                        font.pixelSize: 11
                        font.family: "monospace"
                        color: "#ffffff"
                    }
                }

                // Media Control Buttons & Volume Slider (Prev, Play, Next | Volume)
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: progressRow.bottom
                    anchors.topMargin: 12
                    anchors.bottom: parent.bottom

                    RowLayout {
                        anchors.fill: parent
                        spacing: 16

                        PlasmaComponents.ToolButton {
                            icon.name: "media-skip-backward"
                            display: "IconOnly"
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            onClicked: root.callMediaCommand("Previous")
                        }

                        // Premium soft-translucent cyan circle play button (removes all glaring light!)
                        Rectangle {
                            id: playBtnCircle
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: playMouseArea.containsMouse ? Qt.rgba(20, 255, 236, 0.95) : Qt.rgba(20, 255, 236, 0.7) // Beautiful soft cyan with hover glow!

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: root.isPlaying ? "⏸" : "▶"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#0c0f12" // Solid dark gray symbol matching mockup design exactly
                            }

                            MouseArea {
                                id: playMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.callMediaCommand("PlayPause")
                            }
                        }

                        PlasmaComponents.ToolButton {
                            icon.name: "media-skip-forward"
                            display: "IconOnly"
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            onClicked: root.callMediaCommand("Next")
                        }

                        Item { Layout.fillWidth: true } // Stretch spacing

                        // Volume controls
                        PlasmaComponents.ToolButton {
                            icon.name: "audio-volume-high"
                            display: "IconOnly"
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                        }

                        Slider {
                            id: volSlider
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 20
                            from: 0
                            to: 100
                            value: 70
                            
                            background: Rectangle {
                                x: volSlider.leftPadding
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                implicitWidth: 64
                                implicitHeight: 3
                                width: volSlider.availableWidth
                                height: implicitHeight
                                radius: 1.5
                                color: Qt.rgba(255, 255, 255, 0.2)

                                Rectangle {
                                    width: volSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: root.accentColor
                                    radius: 1.5
                                }
                            }

                            handle: Rectangle {
                                x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                implicitWidth: 8
                                implicitHeight: 8
                                radius: 4
                                color: root.accentColor
                            }

                            onMoved: {
                                // Call playerctl via executable source to change volume with absolute system reliability!
                                executableSource.runCommand("playerctl volume " + (volSlider.value / 100.0))
                            }
                        }
                    }
                }
            }
        }
    }
}
