import QtQuick 2.15

Item {
    id: root
    property bool isPlaying: false
    property var heights: [
        12, 24, 32, 18, 14, 28, 36, 20, 16, 30, 22, 10, 26, 18, 8
    ]
    property real phase: 0.0

    Row {
        spacing: 3
        anchors.centerIn: parent

        Repeater {
            model: 15
            delegate: Rectangle {
                width: 3
                height: {
                    if (root.isPlaying) {
                        var baseHeight = root.heights[index % root.heights.length]
                        var wave = Math.sin(root.phase * 2.0 + index * 0.8) * 0.45 + 0.55
                        return Math.max(4, baseHeight * wave)
                    } else {
                        return Math.max(4, 6 + Math.sin(root.phase + index * 0.5) * 2)
                    }
                }
                radius: 1.5
                color: root.isPlaying ? Qt.rgba(255, 255, 255, 0.9) : Qt.rgba(255, 255, 255, 0.4)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation {
                        duration: root.isPlaying ? 80 : 250
                        easing.type: Easing.InOutQuad
                    }
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
