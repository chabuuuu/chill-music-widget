import QtQuick 2.15

Item {
    width: 200
    height: 200

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    console.log("XHR read: " + xhr.responseText);
                }
            }
            xhr.open("GET", "file:///dev/shm/chill_music_cava.txt?t=" + Date.now(), true);
            xhr.send();
        }
    }
}
