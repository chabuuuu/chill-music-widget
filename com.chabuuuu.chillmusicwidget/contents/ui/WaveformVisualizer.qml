import QtQuick 2.15
import QtWebSockets 1.15

Item {
    id: root
    property bool isPlaying: false
    property var heights: [
        12, 24, 32, 18, 14, 28, 36, 20, 16, 30, 22, 10, 26, 18, 8
    ]
    property real phase: 0.0
    
    // Real-time audio data from CAVA
    property var realHeights: []
    property bool useRealData: false

    Row {
        spacing: 3
        anchors.centerIn: parent

        Repeater {
            model: 15
            delegate: Rectangle {
                width: 3
                height: {
                    if (root.useRealData && root.realHeights.length === 15 && root.isPlaying) {
                        // Real-time audio waveform from CAVA!
                        return Math.max(4, root.realHeights[index])
                    } else if (root.isPlaying) {
                        // High-fidelity fallback animation when player is starting/connecting
                        var baseHeight = root.heights[index % root.heights.length]
                        var wave = Math.sin(root.phase * 2.0 + index * 0.8) * 0.45 + 0.55
                        return Math.max(4, baseHeight * wave)
                    } else {
                        // Gentle slow breathing when music is paused
                        return Math.max(4, 6 + Math.sin(root.phase + index * 0.5) * 2)
                    }
                }
                radius: 1.5
                color: root.isPlaying ? Qt.rgba(20, 255, 236, 0.95) : Qt.rgba(255, 255, 255, 0.4) // Glowing cyan bars when playing!
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation {
                        duration: root.useRealData ? 40 : (root.isPlaying ? 80 : 250) // Ultra-fast response for real-time audio!
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    // --- local WebSocket Connection to Python CAVA server ---
    WebSocket {
        id: socket
        url: "ws://localhost:24862"
        active: root.isPlaying // Auto-connect only when playing to save CPU!
        
        onTextMessageReceived: {
            var parts = message.split(",");
            if (parts.length === 15) {
                var newHeights = [];
                for (var i = 0; i < 15; i++) {
                    newHeights.push(Number(parts[i]));
                }
                root.realHeights = newHeights;
                root.useRealData = true;
            }
        }
        
        onStatusChanged: {
            if (socket.status === WebSocket.Error || socket.status === WebSocket.Closed) {
                root.useRealData = false;
                if (root.isPlaying) {
                    reconnectTimer.start(); // Auto-reconnect
                }
            }
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.isPlaying) {
                socket.active = false;
                socket.active = true;
            }
        }
    }

    Timer {
        id: animTimer
        interval: 50 // 20 FPS fallback updates
        running: !root.useRealData // Run only when not using real data to save CPU!
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
