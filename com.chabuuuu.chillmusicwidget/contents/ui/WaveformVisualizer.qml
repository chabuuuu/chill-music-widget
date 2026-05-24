import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: root
    property bool isPlaying: false
    property real phase: 0.0
    
    // Internal height arrays
    property var realHeights: [4,4,4,4,4,4,4,4,4,4,4,4,4,4,4]
    property var targetHeights: [4,4,4,4,4,4,4,4,4,4,4,4,4,4,4]
    property bool useRealData: false
    
    // Command to launch CAVA with coreutils line-buffering to bypass block cache lag
    property string cavaCmd: "stdbuf -oL cava -p /home/haphuthinh/.config/chill-music-widget/cava_plasmoid.conf"
    
    // Buffer for chunked stdout streams
    property string streamBuffer: ""

    Row {
        spacing: 4
        anchors.centerIn: parent

        Repeater {
            id: visualizerRepeater
            model: 15
            delegate: Rectangle {
                width: 3
                height: 4
                radius: 1.5
                color: root.isPlaying ? Qt.rgba(20, 255, 236, 0.95) : Qt.rgba(255, 255, 255, 0.4)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // --- Fast XHR Shared Memory File Reader ---
    function fetchCavaData() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    var line = xhr.responseText ? xhr.responseText.trim() : "";
                    if (line) {
                        if (line.endsWith(";")) {
                            line = line.substring(0, line.length - 1);
                        }
                        var parts = line.split(";");
                        if (parts.length >= 30) {
                            var parsed = [];
                            for (var j = 0; j < 15; j++) {
                                var cavaIndex = j * 2;
                                var val = Number(parts[cavaIndex]);
                                if (isNaN(val)) val = 0;
                                var h = (val / 36.0) * 24.0;
                                var mult = 0.7 + (j / 14.0) * 0.9;
                                parsed.push(Math.max(4, h * mult));
                            }
                            root.targetHeights = parsed;
                            root.useRealData = true;
                        }
                    }
                }
            }
        }
        // Cache bust to always read latest data
        xhr.open("GET", "http://127.0.0.1:28421/?t=" + Date.now(), true);
        xhr.send();
    }

    // --- Local CAVA Bridge Process Launcher ---
    PlasmaCore.DataSource {
        id: cavaBridgeLauncher
        engine: "executable"
        connectedSources: []
        onNewData: disconnectSource(sourceName) // Run and clean once!
        
        function runCommand(cmd) {
            connectSource(cmd)
        }
    }

    // Connect/Disconnect CAVA bridge dynamically based on playback to save 100% CPU when idle!
    onIsPlayingChanged: {
        if (root.isPlaying) {
            cavaBridgeLauncher.runCommand("pkill -f cava_bridge.py; python3 /home/haphuthinh/.local/share/plasma/plasmoids/com.chabuuuu.chillmusicwidget/contents/ui/cava_bridge.py &");
        } else {
            cavaBridgeLauncher.runCommand("pkill -f cava_bridge.py");
            root.useRealData = false;
        }
    }

    Component.onCompleted: {
        if (root.isPlaying) {
            cavaBridgeLauncher.runCommand("pkill -f cava_bridge.py; python3 /home/haphuthinh/.local/share/plasma/plasmoids/com.chabuuuu.chillmusicwidget/contents/ui/cava_bridge.py &");
        }
    }
    
    Component.onDestruction: {
        cavaBridgeLauncher.runCommand("pkill -f cava_bridge.py");
    }

    // --- High-Performance 60 FPS Visual Inertia Interpolation Clock ---
    Timer {
        id: renderTimer
        interval: 16 // ~60 FPS
        running: true
        repeat: true
        property int tick: 0
        onTriggered: {
            if (root.isPlaying) {
                root.phase += 0.25;
                
                // Read CAVA from zero-latency memory every 2 ticks (approx 32ms / 30 FPS)
                // This keeps visual rendering ultra-smooth at 60 FPS, while keeping process execution very light!
                tick++;
                if (tick % 2 === 0) {
                    fetchCavaData();
                }
                
                // Interpolate real heights towards targets using professional rise/fall decay filter
                if (root.useRealData && root.targetHeights.length === 15) {
                    var smoothed = [];
                    for (var k = 0; k < 15; k++) {
                        var target = root.targetHeights[k];
                        var current = root.realHeights[k];
                        // Relaxing, smooth decay coefficients
                        var decay = target > current ? 0.14 : 0.08;
                        var val = current * (1.0 - decay) + target * decay;
                        smoothed.push(val);
                        
                        // Update visual bar height directly
                        var item = visualizerRepeater.itemAt(k);
                        if (item) {
                            item.height = val;
                        }
                    }
                    root.realHeights = smoothed;
                } else {
                    // Buffering / Playing breathing wave
                    for (var i = 0; i < 15; i++) {
                        var wave = Math.sin(root.phase * 2.0 - i * 0.4) * 0.4 + 0.6;
                        var baseHeight = 8 + (i / 14.0) * 12;
                        var item = visualizerRepeater.itemAt(i);
                        if (item) {
                            item.height = Math.max(4, baseHeight * wave);
                        }
                    }
                }
            } else {
                root.phase += 0.05;
                root.useRealData = false;
                
                // Paused ambient wave
                for (var i = 0; i < 15; i++) {
                    var wave = Math.sin(root.phase - i * 0.3) * 0.3 + 0.7;
                    var baseHeight = 6 + (i / 14.0) * 6;
                    var item = visualizerRepeater.itemAt(i);
                    if (item) {
                        item.height = Math.max(4, baseHeight * wave);
                    }
                }
            }
        }
    }
}
