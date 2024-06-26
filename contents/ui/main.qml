/*
* SPDX-FileCopyrightText: 2014, 2016 Mikhail Ivchenko <ematirov@gmail.com>
* SPDX-FileCopyrightText: 2018 Kai Uwe Broulik <kde@privat.broulik.de>
* SPDX-FileCopyrightText: 2020 Sora Steenvoort <sora@dillbox.me>
*
* SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtWebEngine
import QtQuick.Layouts 1.1
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0


import org.kde.plasma.components 3.0 as PC3

PlasmoidItem {
    id: googleroot

    switchWidth: Kirigami.Units.gridUnit * 16
    switchHeight: Kirigami.Units.gridUnit * 23

    // Only exists because the default CompactRepresentation doesn't expose
    // a way to display arbitrary images; it can only show icons.
    // TODO remove once it gains that feature.
    compactRepresentation: Loader {
        id: favIconLoader
        active: Plasmoid.configuration.useFavIcon
        asynchronous: true
        sourceComponent: Image {
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectFit
            source: Plasmoid.configuration.favIcon
        }

        TapHandler {
            property bool wasExpanded: false

                acceptedButtons: Qt.LeftButton

                onPressedChanged: if (pressed) {
                wasExpanded = googleroot.expanded;
            }
            onTapped: googleroot.expanded = !wasExpanded
        }

        Kirigami.Icon {
            anchors.fill: parent
            visible: favIconLoader.item?.status !== Image.Ready
            source: Plasmoid.configuration.icon || Plasmoid.icon
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: googleroot.switchWidth
        Layout.minimumHeight: googleroot.switchHeight

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.Button {
                // icon.name: "Go Home"
                text: i18nc("@action:button", "Go Home")

                onClicked: {
                    var googleurl = 'https://google.com/'
                    googlewebview.url = googleurl ;
                }
            }


            PlasmaComponents3.Button {
                icon.name: "go-previous"
                onClicked: googlewebview.goBack()
                enabled: googlewebview.canGoBack
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18nc("@action:button", "Go Back")
            }
            PlasmaComponents3.Button {
                icon.name: "go-next"
                onClicked: googlewebview.goForward()
                enabled: googlewebview.canGoForward
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18nc("@action:button", "Go Forward")
            }
            PlasmaComponents3.TextField {
                Layout.fillWidth: true
                onAccepted: {
                    var url = text;
                    if (url.indexOf(":/") < 0)
                    {
                        url = "http://" + url;
                    }
                    googlewebview.url = url;
                }
                onActiveFocusChanged: {
                    if (activeFocus)
                    {
                        selectAll();
                    }
                }

                text: googlewebview.url

                Accessible.description: text.length > 0 ? text : i18nc("@info", "Type a URL")
            }

            // this shows page-related information such as blocked popups
            PlasmaComponents3.ToolButton {
                id: infoButton

                // callback invoked when button is clicked
                property var cb

                // button itself adds sufficient visual padding
                Layout.leftMargin: -parent.spacing
                Layout.rightMargin: -parent.spacing

                onClicked: cb();

                PlasmaComponents3.ToolTip {
                    id: tooltip
                }

                function show(text, icon, tooltipText, cb)
                {
                    infoButton.text = text;
                    infoButton.icon.name = icon;
                    tooltip.text = tooltipText;
                    infoButton.cb = cb;
                    infoButton.visible = true;
                }

                function dismiss()
                {
                    infoButton.visible = false;
                }
            }

            PlasmaComponents3.Button {
                display: PlasmaComponents3.AbstractButton.IconOnly
                icon.name: googlewebview.loading ? "process-stop" : "view-refresh"
                text: googlewebview.loading ? i18nc("@action:button", "Stop Loading This Page") : i18nc("@action:button", "Reload This Page")
                onClicked: googlewebview.loading ? googlewebview.stop() : googlewebview.reload()
            }

            PlasmaComponents3.ToolButton {
                display: PlasmaComponents3.AbstractButton.IconOnly
                visible: !onDesktop
                icon.name: 'configure'
                text: Plasmoid.internalAction("configure").text

                onClicked: {
                    Plasmoid.internalAction("configure").trigger()
                }

                PlasmaComponents3.ToolTip {
                    text: parent.text
                }
            }
            PlasmaComponents3.ToolButton {
                display: PlasmaComponents3.AbstractButton.IconOnly

                visible: !onDesktop

                icon.name: 'pin'

                text: i18n("Keep Open")

                checked: !autoHide

                onClicked: {
                    autoHide = !autoHide
                    main.hideOnWindowDeactivate = autoHide
                }

                PlasmaComponents3.ToolTip {
                    text: parent.text
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // TODO use contentsSize but that crashes, now mostly for some sane initial size
            Layout.preferredWidth: Kirigami.Units.gridUnit * 40
            Layout.preferredHeight: Kirigami.Units.gridUnit * 100

            // Binding it to e.g. width will be super slow on resizing
            Timer {
                id: updateZoomTimer
                interval: 100

                readonly property int minViewWidth: plasmoid.configuration.minViewWidth
                    readonly property bool useMinViewWidth: plasmoid.configuration.useMinViewWidth
                        readonly property int constantZoomFactor: plasmoid.configuration.constantZoomFactor

                            onTriggered: {
                                var newZoom = 1;
                                if (useMinViewWidth)
                                {
                                    // Try to fit contents for a smaller screen
                                    newZoom = Math.min(1, googlewebview.width / minViewWidth);
                                    // make sure value is valid
                                    newZoom = Math.max(0.25, newZoom);
                                } else {
                                newZoom = constantZoomFactor / 100.0;
                            }
                            googlewebview.zoomFactor = newZoom;
                            // setting the zoom factor does not always work on the first try; also, numbers get rounded
                            if (Math.round(1000 * googlewebview.zoomFactor) != Math.round(1000 * newZoom))
                            {
                                updateZoomTimer.restart();
                            }
                        }
                    }

                    // This reimplements WebEngineView context menu for links to add a "open externally" entry
                    // since you cannot add custom items there yet
                    // there's a FIXME comment about that in QQuickWebEngineViewPrivate::contextMenuRequested
                    PlasmaExtras.Menu {
                        id: linkContextMenu
                        visualParent: googlewebview

                        property string link

                        PlasmaExtras.MenuItem {
                            text: i18nc("@action:inmenu", "Open Link in Browser")
                            icon: "internet-web-browser"
                            onClicked: Qt.openUrlExternally(linkContextMenu.link)
                        }

                        PlasmaExtras.MenuItem {
                            text: i18nc("@action:inmenu", "Copy Link Address")
                            icon: "edit-copy"
                            onClicked: googlewebview.triggerWebAction(WebEngineView.CopyLinkToClipboard)
                        }
                    }

                    WebEngineView {
                        id: googlewebview
                        anchors.fill: parent
                        onUrlChanged: plasmoid.configuration.url = url;
                        Component.onCompleted: url = plasmoid.configuration.url;

                        readonly property bool useMinViewWidth: plasmoid.configuration.useMinViewWidthh




                            WebEngineProfile {
                                id: googleProfile
                                httpUserAgent: getUserAgent()
                                storageName: "google"
                                offTheRecord: false
                                httpCacheType: WebEngineProfile.DiskHttpCache
                                persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
                            }

                            profile: googleProfile



                            Connections {
                                target: plasmoid.configuration

                                function onMinViewWidthChanged()
                                {updateZoomTimer.start()}

                                    function onUseMinViewWidthChanged()
                                    {updateZoomTimer.start()}

                                        function onConstantZoomFactorChanged()
                                        {updateZoomTimer.start()}

                                            function onUseConstantZoomChanged()
                                            {updateZoomTimer.start()}
                                            }

                                            onLinkHovered: hoveredUrl => {
                                            if (hoveredUrl.toString() !== "")
                                            {
                                                mouseArea.cursorShape = Qt.PointingHandCursor;
                                            } else {
                                            mouseArea.cursorShape = Qt.ArrowCursor;
                                        }
                                    }

                                    onWidthChanged: {
                                        if (useMinViewWidth)
                                        {
                                            updateZoomTimer.start()
                                        }
                                    }

                                    onLoadingChanged: loadingInfo => {
                                    if (loadingInfo.status === WebEngineLoadingInfo.LoadStartedStatus)
                                    {
                                        infoButton.dismiss();
                                    } else if (loadingInfo.status === WebEngineLoadingInfo.LoadSucceededStatus && useMinViewWidth) {
                                    updateZoomTimer.start();
                                }
                            }

                            onContextMenuRequested: request => {
                            if (request.mediaType === ContextMenuRequest.MediaTypeNone && request.linkUrl.toString() !== "")
                            {
                                linkContextMenu.link = request.linkUrl;
                                linkContextMenu.open(request.position.x, request.position.y);
                                request.accepted = true;
                            }
                        }

                        onNavigationRequested: request => {
                        var url = request.url;

                        if (request.userInitiated)
                        {
                            Qt.openUrlExternally(url);
                        } else {
                        infoButton.show(i18nc("An unwanted popup was blocked", "Popup blocked"), "document-close",
                        i18n("Click here to open the following blocked popup:\n%1", url), function () {
                        Qt.openUrlExternally(url);
                        infoButton.dismiss();
                    });
                }
            }

            onIconChanged: {
                if (loading && icon == "")
                {
                    return;
                }
                Plasmoid.configuration.favIcon = icon.toString().slice(16 /* image://favicon/ */);
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            acceptedButtons: Qt.BackButton | Qt.ForwardButton
            onPressed: mouse => {
            if (mouse.button === Qt.BackButton)
            {
                googlewebview.goBack();
            } else if (mouse.button === Qt.ForwardButton) {
            googlewebview.goForward();
        }
    }
}
}
}
}
