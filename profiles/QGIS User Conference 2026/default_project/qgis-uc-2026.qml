import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtCore

import org.qfield
import org.qgis
import Theme

Item {
  id: plugin

  property var mainWindow: iface.mainWindow()
  property var mapCanvas: iface.mapCanvas()
  property var featureForm: iface.findItemByObjectName('featureForm')
  
  property var roomsLayer: undefined
  property var eventsLayer: undefined
  property var speakersLayer: undefined
  property var eventsToSpeakersLayer: undefined

  Component.onCompleted: {
    roomsLayer = qgisProject.mapLayersByName("Rooms")[0];
    eventsLayer = qgisProject.mapLayersByName("Events")[0];
    speakersLayer = qgisProject.mapLayersByName("Speakers")[0];
    eventsToSpeakersLayer = qgisProject.mapLayersByName("events_to_speakers")[0];

    iface.addItemToPluginsToolbar(eventsButton)
    iface.addItemToPluginsToolbar(speakersButton)
    iface.addItemToPluginsToolbar(favoritesButton)

    Theme.applyAppearance({
                            "mainColor": "#579531",
                            "buttonBackgroundColor": "#579531",
                            "accentColor": "#92af22",
                            "accentLightColor": "#9992af22"
                          }, false)

    fetchSchedule();
  }
  
  Component.onDestruction: {
    Theme.applyAppearance()
  }
  
  Connections {
    target: featureForm.selection
    enabled: sliderContainer.expanded

    function onFocusedItemChanged() {
      if (sliderContainer.expanded) {
        let feature_floor = '';
        if (featureForm.selection.focusedLayer === roomsLayer) {
          feature_floor = featureForm.selection.focusedFeature.attribute("floor");
        } else if (featureForm.selection.focusedLayer === eventsLayer) {
          feature_floor = featureForm.selection.focusedFeature.attribute("Rooms_floor");
        }
        if (feature_floor != '') {
          floorSlider.value = floorSlider.floorNames.indexOf(feature_floor);
        }
      }
    }
  }
  
  Rectangle {
    id: sliderContainer
    parent: mapCanvas
    anchors.left: parent.left
    anchors.leftMargin: 5
    anchors.verticalCenter: parent.verticalCenter
    width: 48
    height: expanded ? (parent.height) * 0.4 : width
    radius: width / 2
    color: "#AA333333"
    clip: true

    Behavior on height  {
      PropertyAnimation {
        easing.type: Easing.OutQuart
      }
    }

    property bool expanded: false

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      Text {
        Layout.fillWidth: true
        Layout.preferredHeight: sliderContainer.expanded ? 48 : 0
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignBottom
        font: Theme.tipFont
        text: "<b>Flr.</b><br>" + floorSlider.floorNames[floorSlider.value]
      }

      Slider {
        id: floorSlider
        
        property var floorNames: ['-1','0','1', '2']
        
        Layout.preferredHeight: sliderContainer.expanded ? 48 : 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: 0
        orientation: Qt.Vertical
        from: 0
        to: 3
        stepSize: 1
        value: 1

        onValueChanged: {
          ExpressionContextUtils.setLayerVariable(roomsLayer, "current_floor", floorSlider.floorNames[floorSlider.value]);
          roomsLayer.triggerRepaint();
        }
      }

      QfToolButton {
        Layout.preferredWidth: 48
        Layout.preferredHeight: 48
        round: true

        bgcolor: Theme.toolButtonBackgroundColor
        iconSource: Qt.resolvedUrl("assets/logo-small.svg")
        iconColor: Theme.toolButtonColor

        onClicked: {
          sliderContainer.expanded = !sliderContainer.expanded;
          
          if (sliderContainer.expanded) {
            let galaaxyDay = new Date("2026-10-05");
            let nowDay = new Date();
            let geometry;
            if (nowDay - galaaxyDay > 2 * 24 * 60 * 60 * 1000) {
              geometry = GeometryUtils.createGeometryFromWkt("Polygon((1031165 5912294, 1031165 5912659, 1031537 5912659, 1031537 5912294, 1031165 5912294))");
            } else {
              geometry = GeometryUtils.createGeometryFromWkt("Polygon((1025783 5915072, 1025783 5915263, 1025978 5915263, 1025978 5915072, 1025783 5915072))");
            }
            let extent = GeometryUtils.boundingBox(geometry);
            let scale = mapCanvas.mapSettings.computeScaleForExtent(extent, true);
            mapCanvas.jumpTo(extent.center, scale, -1, true);

            if (floorSlider.value !== 1) {
              floorSlider.value = 1;
            }

            if (flatLayerTree.mapTheme != "Conference focus") {
              flatLayerTree.mapTheme = "Conference focus"
            }
            
            ExpressionContextUtils.setLayerVariable(roomsLayer, "current_floor", floorSlider.floorNames[floorSlider.value]);
            roomsLayer.triggerRepaint();
          } else {
            ExpressionContextUtils.setLayerVariable(roomsLayer, "current_floor", "");
            roomsLayer.triggerRepaint();
          }
        }
      }
    }
  }
  
  Settings {
    id: settings
    category: "qgis-uc-2026-settings"
    property string favorites: ""  
  }
  
  QfToolButton {
    id: eventsButton
    width: 48
    height: width
    round: true
    iconSource: Qt.resolvedUrl("assets/events.svg")
    iconColor: Theme.toolButtonColor
    bgcolor: Theme.toolButtonBackgroundColor

    onClicked: {
      featureForm.model.setFeatures(eventsLayer, "");
    }
  }
  
  QfToolButton {
    id: speakersButton
    width: 48
    height: width
    round: true
    iconSource: Qt.resolvedUrl("assets/speakers.svg")
    iconColor: Theme.toolButtonColor
    bgcolor: Theme.toolButtonBackgroundColor

    onClicked: {
      featureForm.model.setFeatures(speakersLayer, "");
    }
  }
  
  QfToolButton {
    id: favoritesButton
    width: 48
    height: width
    round: true
    iconSource: Qt.resolvedUrl("assets/star.svg")
    iconColor: Theme.toolButtonColor
    bgcolor: Theme.toolButtonBackgroundColor

    onClicked: {
      let favorites = settings.value("favorites");
      if (favorites === "") {
        mainWindow.displayToast("No favorites added yet, browse the schedule :)");
        return;
      }
      favorites = favorites.split(",");
      let filter = "\"guid\" IN (''";
      for(const favorite of favorites) {
        filter += ",'" + favorite +"'";
      }
      filter += ")";
      
      featureForm.model.setFeatures(eventsLayer, filter);
    }
  }
  
  function fetchSchedule() {
    let xhr = new XMLHttpRequest();
    
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        let response = {
            status : xhr.status,
            headers : xhr.getAllResponseHeaders(),
            contentType : xhr.responseType,
            content : xhr.response
        };

        parseSchedule(xhr.response);
      }
    }

    xhr.open("GET", "https://talks.osgeo.org/qgis-uc2026/schedule/export/schedule.json");
    xhr.send();
  }

  function parseSchedule(content) {
    let eventFeatures = [];
    let speakerFeatures = [];
    let speakerGuids = [];
    let eventToSpeakerFeatures = [];

    let json = JSON.parse(content);
    let days = json.schedule.conference.days;
    let dayIndex = 1;
    for (let day of days) {
      const rooms = day.rooms;
      for (let name in rooms) {
        for (let event of rooms[name]) {
          let eventFeature = FeatureUtils.createBlankFeature(eventsLayer.fields);
          eventFeature.setAttribute("guid", event.guid);
          eventFeature.setAttribute("day", dayIndex);
          eventFeature.setAttribute("room", event.room);
          eventFeature.setAttribute("date", event.date);
          eventFeature.setAttribute("time", event.start);
          eventFeature.setAttribute("type", event.type);
          eventFeature.setAttribute("title", event.title);
          eventFeature.setAttribute("subtitle", event.subtitle);
          eventFeature.setAttribute("abstract", event.abstract);
          eventFeature.setAttribute("description", event.description);
          eventFeature.setAttribute("url", event.url);
          eventFeatures.push(eventFeature);

          for (let person of event.persons) {
            if (speakerGuids.indexOf(person.guid) == -1) {
              speakerGuids.push(person.guid);

              let speakerFeature = FeatureUtils.createBlankFeature(speakersLayer.fields);
              speakerFeature.setAttribute("guid", person.guid);
              speakerFeature.setAttribute("name", person.name);
              speakerFeature.setAttribute("biography", person.biography);
              speakerFeatures.push(speakerFeature);
            }

            let eventToSpeakerFeature = FeatureUtils.createBlankFeature(eventsToSpeakersLayer.fields);
            eventToSpeakerFeature.setAttribute("event_guid", event.guid);
            eventToSpeakerFeature.setAttribute("person_guid", person.guid);
            eventToSpeakerFeatures.push(eventToSpeakerFeature);
          }
        }
      }

      dayIndex++;
    }

    if (eventFeatures.length == 0 || speakerFeatures.length == 0 || eventToSpeakerFeatures.length == 0) {
      // Be safe, don't refresh schedule when nothing's been parsed
      return;
    }

    eventsLayer.readOnly = false;
    eventsLayer.startEditing();
    eventsLayer.selectAll();
    eventsLayer.deleteSelectedFeatures();
    for (let feature of eventFeatures) {
      LayerUtils.addFeature(eventsLayer, feature);
    }
    eventsLayer.commitChanges();
    eventsLayer.readOnly = true;

    speakersLayer.readOnly = false;
    speakersLayer.startEditing();
    speakersLayer.selectAll();
    speakersLayer.deleteSelectedFeatures();
    for (let feature of speakerFeatures) {
      LayerUtils.addFeature(speakersLayer, feature);
    }
    speakersLayer.commitChanges();
    speakersLayer.readOnly = true;

    eventsToSpeakersLayer.startEditing();
    eventsToSpeakersLayer.selectAll();
    eventsToSpeakersLayer.deleteSelectedFeatures();
    for (let feature of eventToSpeakerFeatures) {
      LayerUtils.addFeature(eventsToSpeakersLayer, feature);
    }
    eventsToSpeakersLayer.commitChanges();

    mainWindow.displayToast("Schedule updated");
  }
}
