from PyQt5.QtWidgets import QSlider
from PyQt5.QtCore import Qt

class ClickableSlider(QSlider):
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            if self.orientation() == Qt.Horizontal:
                val = self.minimum() + ((self.maximum() - self.minimum()) * event.x()) / self.width()
            else:
                val = self.minimum() + ((self.maximum() - self.minimum()) * (self.height() - event.y())) / self.height()
            self.setValue(int(val))
            self.sliderReleased.emit()
            event.accept()
        super().mousePressEvent(event)
