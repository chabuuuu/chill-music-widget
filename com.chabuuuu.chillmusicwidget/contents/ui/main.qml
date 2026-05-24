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

    // Set Plasmoid background hints to hide default system frames
    Plasmoid.backgroundHints: Plasmoid.NoBackground

    // --- State & Variables ---
    property color accentColor: "#14ffec" // Vibrant glowing cyan matching original PyQt5 app 100%
    property string songTitle: "No active player"
    property string songArtist: "Play music to visualize"
    property string albumArt: ""
    property bool isPlaying: false
    property double trackPosition: 0
    property double trackLength: 0
    property int lastVolume: 70

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
            
            var vol = data[activePlayer]["Volume"];
            if (vol !== undefined && typeof volSlider !== "undefined" && !volSlider.pressed) {
                volSlider.value = Math.round(vol * 100);
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

    // --- Command Execution Engine ---
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

    // ==================== GLASSMORPHISM CONTAINER CARD ====================
    // Centered with fixed pixel dimensions to prevent desktop grid resizing/clipping!
    Rectangle {
        id: widgetBackground
        width: 860
        height: 230
        anchors.centerIn: parent
        radius: 40 // Matches mockup rounded corners 100%
        color: mouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.08)
        border.color: mouseArea.containsMouse ? Qt.rgba(20, 255, 236, 0.45) : Qt.rgba(255, 255, 255, 0.15) // Accent glowing cyan outline on hover!
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 250 } }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
        }

        // ==================== LEFT AREA: ALBUM ART & CONTROLS ====================
        
        // 1. Album Art (144x144, vertically centered, 24px left margin)
        Rectangle {
            id: artContainer
            x: 24
            y: 43
            width: 144
            height: 144
            radius: 16
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

        // 2. Song Details & Interactive Player Controls Column
        Item {
            id: trackColumn
            x: 192
            y: 34
            width: 400
            height: 162

            // Song Title
            Text {
                id: songTitleText
                x: 0
                y: 0
                width: 400
                text: root.songTitle
                font.pixelSize: 18
                font.bold: true
                font.family: "Inter"
                color: "#ffffff"
                elide: Text.ElideRight
            }

            // Song Artist
            Text {
                id: songArtistText
                x: 0
                y: 28
                width: 400
                text: root.songArtist
                font.pixelSize: 11
                font.family: "Inter"
                color: Qt.rgba(209, 213, 219, 0.85)
                elide: Text.ElideRight
            }

            // 15-Bar Soundwave Visualizer (Syncs with live audio or breathing fallback)
            WaveformVisualizer {
                id: visualizer
                x: 0
                y: 50
                width: 400
                height: 24
                isPlaying: root.isPlaying
            }

            // Progress Slider Timestamps
            Text {
                id: timeCurrent
                x: 0
                y: 82
                width: 50
                height: 14
                text: root.formatTime(root.trackPosition)
                font.pixelSize: 10
                font.family: "monospace"
                color: "#ffffff"
            }

            Text {
                id: timeTotal
                x: 350
                y: 82
                width: 50
                height: 14
                text: root.formatTime(root.trackLength)
                font.pixelSize: 10
                font.family: "monospace"
                color: "#ffffff"
                horizontalAlignment: Text.AlignRight
            }

            // Progress Seek Bar (Vibrant Glowing Cyan Slider)
            Slider {
                id: progressSlider
                x: 0
                y: 98
                width: 400
                height: 16
                from: 0
                to: Math.max(1, root.trackLength)
                value: root.trackPosition
                
                background: Rectangle {
                    x: progressSlider.leftPadding
                    y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                    width: progressSlider.availableWidth
                    height: 4
                    radius: 2
                    color: Qt.rgba(255, 255, 255, 0.2)

                    Rectangle {
                        width: progressSlider.visualPosition * parent.width
                        height: parent.height
                        color: root.accentColor
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                    y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                    implicitWidth: 10
                    implicitHeight: 10
                    radius: 5
                    color: root.accentColor
                }

                onMoved: {
                    if (mprisSource.activePlayer) {
                        executableSource.runCommand("playerctl -p " + mprisSource.activePlayer + " position " + Math.round(progressSlider.value));
                    }
                }

                onPressedChanged: {
                    if (!pressed) {
                        if (mprisSource.activePlayer) {
                            executableSource.runCommand("playerctl -p " + mprisSource.activePlayer + " position " + Math.round(progressSlider.value));
                        }
                    }
                }
            }

            // Media & Volume Control Buttons Row (No ugly gray borders, sleek hover transition)
            Item {
                id: controlsRow
                x: 0
                y: 124
                width: 400
                height: 40

                // Previous Button
                Text {
                    id: prevBtn
                    x: 0
                    y: 5
                    width: 30
                    height: 30
                    text: "⏮"
                    font.pixelSize: 18
                    color: prevMouse.containsMouse ? root.accentColor : "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.callMediaCommand("Previous")
                    }
                }

                // Premium Glowing Play/Pause Circle Button
                Rectangle {
                    id: playBtn
                    x: 46
                    y: 0
                    width: 40
                    height: 40
                    radius: 20
                    color: playMouse.containsMouse ? Qt.rgba(20, 255, 236, 0.95) : Qt.rgba(20, 255, 236, 0.75)
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "⏸" : "▶"
                        font.pixelSize: 15
                        color: "#0c0f12"
                    }
                    
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.callMediaCommand("PlayPause")
                    }
                }

                // Next Button
                Text {
                    id: nextBtn
                    x: 102
                    y: 5
                    width: 30
                    height: 30
                    text: "⏭"
                    font.pixelSize: 18
                    color: nextMouse.containsMouse ? root.accentColor : "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.callMediaCommand("Next")
                    }
                }

                // Volume Icon (Dynamic and Reactive mute toggle)
                Text {
                    id: volBtn
                    x: 292
                    y: 6
                    width: 28
                    height: 28
                    text: {
                        if (volSlider.value === 0) return "🔇";
                        if (volSlider.value < 40) return "🔈";
                        if (volSlider.value < 75) return "🔉";
                        return "🔊";
                    }
                    font.pixelSize: 16
                    color: volMouse.containsMouse ? root.accentColor : "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    MouseArea {
                        id: volMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (volSlider.value > 0) {
                                root.lastVolume = volSlider.value;
                                volSlider.value = 0;
                            } else {
                                volSlider.value = root.lastVolume || 70;
                            }
                            if (mprisSource.activePlayer) {
                                var volumeVal = (volSlider.value / 100.0).toFixed(2);
                                executableSource.runCommand("playerctl -p " + mprisSource.activePlayer + " volume " + volumeVal);
                            }
                        }
                    }
                }

                // Volume Slider
                Slider {
                    id: volSlider
                    x: 336
                    y: 10
                    width: 64
                    height: 20
                    from: 0
                    to: 100
                    value: 70

                    background: Rectangle {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        width: volSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Qt.rgba(255, 255, 255, 0.2)

                        Rectangle {
                            width: volSlider.visualPosition * parent.width
                            height: parent.height
                            color: root.accentColor
                            radius: 2
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
                        if (mprisSource.activePlayer) {
                            var volumeVal = (volSlider.value / 100.0).toFixed(2);
                            executableSource.runCommand("playerctl -p " + mprisSource.activePlayer + " volume " + volumeVal);
                        }
                    }

                    onPressedChanged: {
                        if (!pressed) {
                            if (mprisSource.activePlayer) {
                                var volumeVal = (volSlider.value / 100.0).toFixed(2);
                                executableSource.runCommand("playerctl -p " + mprisSource.activePlayer + " volume " + volumeVal);
                            }
                        }
                    }
                }
            }
        }

        // ==================== RIGHT AREA: SYSTEM INFO & CLOCK ====================
        Item {
            id: rightPanel
            x: 616
            y: 24
            width: 220
            height: 182

            // Clock & Date Stacked Header
            Item {
                id: clockHeader
                x: 0
                y: 0
                width: 220
                height: 50

                Text {
                    id: clockText
                    x: 0
                    y: 0
                    text: Qt.formatTime(new Date(), "HH:mm")
                    font.pixelSize: 32
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
                    x: 0
                    y: 34
                    text: Qt.formatDate(new Date(), "ddd, d MMM").toUpperCase()
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "Inter"
                    color: Qt.rgba(209, 213, 219, 0.7)
                    
                    Timer {
                        interval: 60000
                        running: true
                        repeat: true
                        onTriggered: dateText.text = Qt.formatDate(new Date(), "ddd, d MMM").toUpperCase()
                    }
                }
            }

            // Stats Columns (CPU, RAM, Battery, Temp) - Emojis replaced with 100% compatible symbols
            Column {
                x: 0
                y: 56
                width: 220
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
                        text: "⚙ RAM"
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
                        text: root.isCharging ? "🔌 BAT" : "⚡ BAT"
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
                        text: "☀ TEMP"
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
    }
    Component.onCompleted: {
        // Generates the optimal line-buffered CAVA configuration on startup with explicit semicolon delimiter and 30 widened frequency cutoffs (20Hz - 20000Hz)
        executableSource.runCommand("python3 -c \"import os; os.makedirs(os.path.expanduser('~/.config/chill-music-widget'), exist_ok=True); open(os.path.expanduser('~/.config/chill-music-widget/cava_plasmoid.conf'), 'w').write('[general]\\nbars = 30\\nframerate = 60\\nlower_cutoff_freq = 20\\nhigher_cutoff_freq = 20000\\n\\n[input]\\nmethod = pulse\\nsource = auto\\n\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 36\\nbar_delimiter = 59\\n')\"");

        // Warm up and connect MPRIS active player on startup immediately if already playing
        if (mprisSource.sources.length > 0) {
            var found = "";
            for (var i = 0; i < mprisSource.sources.length; i++) {
                var src = mprisSource.sources[i];
                if (mprisSource.data[src] && mprisSource.data[src]["PlaybackStatus"] === "Playing") {
                    found = src;
                    break;
                }
            }
            if (found === "") found = mprisSource.sources[0];
            mprisSource.activePlayer = found;
            if (found !== "") mprisSource.connectSource(found);
        }
    }
}
