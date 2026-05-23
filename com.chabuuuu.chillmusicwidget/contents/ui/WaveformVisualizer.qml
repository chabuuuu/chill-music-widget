import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: root
    property bool isPlaying: false
    property var heights: [
        12, 24, 32, 18, 14, 28, 36, 20, 16, 30, 22, 10, 26, 18, 8
    ]
    property real phase: 0.0
    
    // Real-time CAVA data
    property var realHeights: []
    property bool useRealData: false
    
    // CAVA config path in user home directory
    property string cavaCmd: "cava -p ~/.config/chill-music-widget/cava.conf"

    Row {
        spacing: 3
        anchors.centerIn: parent

        Repeater {
            model: 15
            delegate: Rectangle {
                width: 3
                height: {
                    if (root.useRealData && root.realHeights.length === 15 && root.isPlaying) {
                        return Math.max(4, root.realHeights[index])
                    } else if (root.isPlaying) {
                        var baseHeight = root.heights[index % root.heights.length]
                        var wave = Math.sin(root.phase * 2.0 + index * 0.8) * 0.45 + 0.55
                        return Math.max(4, baseHeight * wave)
                    } else {
                        return Math.max(4, 6 + Math.sin(root.phase + index * 0.5) * 2)
                    }
                }
                radius: 1.5
                color: root.isPlaying ? Qt.rgba(20, 255, 236, 0.95) : Qt.rgba(255, 255, 255, 0.4)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation {
                        duration: root.useRealData ? 40 : (root.isPlaying ? 80 : 250)
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    // --- Native 60 FPS CAVA Stream Engine (No WebSockets needed!) ---
    PlasmaCore.DataSource {
        id: cavaSource
        engine: "executable"
        connectedSources: []
        
        onNewData: {
            // sourceName contains the executable command string
            if (sourceName === root.cavaCmd) {
                var stdout = data[sourceName]["stdout"];
                if (stdout) {
                    var lines = stdout.trim().split("\n");
                    var lastLine = lines[lines.length - 1].trim();
                    if (lastLine.indexOf(";") !== -1) {
                        if (lastLine.endsWith(";")) {
                            lastLine = lastLine.substring(0, lastLine.length - 1);
                        }
                        var parts = lastLine.split(";");
                        if (parts.length >= 15) {
                            var newHeights = [];
                            for (var i = 0; i < 15; i++) {
                                newHeights.push(Number(parts[i]));
                            }
                            root.realHeights = newHeights;
                            root.useRealData = true;
                        }
                    }
                }
            }
        }
    }

    // Connect/Disconnect CAVA dynamically based on playback to save 100% CPU when idle!
    onIsPlayingChanged: {
        if (root.isPlaying) {
            cavaSource.connectSource(root.cavaCmd);
        } else {
            cavaSource.disconnectSource(root.cavaCmd);
            root.useRealData = false;
        }
    }

    Timer {
        id: animTimer
        interval: 50
        running: !root.useRealData
        repeat: true
        onTriggered: {
            if (root.isPlaying) {
                root.phase += 0.25
            } else {
                root.phase += 0.05
            }
        }
    }
}
