import QtQuick 2.15

Row {
    id: root
    spacing: 3
    alignment: Qt.AlignHCenter | Qt.AlignVCenter

    property bool isPlaying: false
    property var heights: [
        12, 24, 32, 18, 14, 28, 36, 20, 16, 30, 22, 10, 26, 18, 8
    ]
    property real phase: 0.0

    Repeater {
        model: 15
        delegate: Rectangle {
            width: 3
            height: {
                if (!root.isPlaying) {
                    // Breathing effect when paused
                    return Math.max(4, 6 + Math.sin(root.phase + index * 0.5) * 2)
                } else {
                    // Dynamic waveform simulation when playing
                    var baseHeight = root.heights[index % root.heights.length]
                    var wave = Math.sin(root.phase * 2.0 + index * 0.8) * 0.45 + 0.55
                    return Math.max(4, baseHeight * wave)
                }
            }
            radius: 1.5
            color: root.isPlaying ? Qt.rgba(255, 255, 255, 0.9) : Qt.rgba(255, 255, 255, 0.4)

            // Smooth height transitions
            Behavior on height {
                NumberAnimation {
                    duration: root.isPlaying ? 80 : 250
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    Timer {
        id: animTimer
        interval: 50 // 20 FPS updates
        running: true
        repeat: true
        onTriggered: {
            if (root.isPlaying) {
                root.phase += 0.25
            } else {
                root.phase += 0.05 // Slow breathing
            }
        }
    }
}
