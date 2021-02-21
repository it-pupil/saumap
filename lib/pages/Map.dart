import 'package:flutter/material.dart';
import 'package:flutter_bmfbase/BaiduMap/bmfmap_base.dart';
import 'package:flutter_bmfmap/BaiduMap/bmfmap_map.dart';
import 'package:saumap/apis.dart';
import 'package:saumap/pages/components/Dialog.dart';
import 'package:saumap/pages/components/Locate.dart';
import 'package:saumap/pages/line/add.dart';
import 'package:saumap/pages/marker/add.dart';
import 'package:saumap/pages/marker/find.dart';
import 'package:saumap/pages/marker/markerArguments.dart';
import 'package:toast/toast.dart';
import 'components/MyTextField.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  BMFMapOptions mapOptions;
  BMFMapController ctl;

  bool addMarker = false;
  bool deleteMarker = false;
  String where;

  List markers;
  Map _clickedMarker;

  Map myLocate;
  BMFPolyline path;
  Map<String, String> whereType;

  @override
  void initState() {
    super.initState();
    mapOptions = BMFMapOptions(
        center: BMFCoordinate(41.932551, 123.410423),
        zoomLevel: 18,
        mapPadding: BMFEdgeInsets(left: 30, top: 0, right: 30, bottom: 0));

    // 设置监听当前位置，更新位置
    var listener = getLocate();
    listener().listen((Map<String, Object> result) {
      ctl?.updateLocationData(BMFUserLocation(
        location: BMFLocation(
            coordinate: BMFCoordinate(result['latitude'], result['longitude']),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: -1.0,
            speed: -1.0,
            course: -1.0),
      ));

      myLocate = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: MyTextField(
            placeholder: "想去哪？",
            theme: 'dark',
            onChange: (d) => where = d,
          ),
          actions: [
            IconButton(
                icon: Icon(Icons.search),
                onPressed: () async {
                  var from = myLocate['latitude'].toString() +
                      ',' +
                      myLocate['longitude'].toString();
                  whereType = getType(where, markers);
                  var response = await dio.get(getPathsUrl, queryParameters: {
                    "to": whereType['to'],
                    "from": from,
                    "type": whereType['type'],
                  });

                  List points = response.data;
                  if (points.length == 0) {
                    Toast.show("未标注！", context, gravity: Toast.TOP);
                  }

                  ctl?.removeOverlay(path?.getId());
                  path = addLine(
                    ctl,
                    points,
                  );
                }),
          ],
        ),
        body: Stack(children: [
          BMFMapWidget(
            onBMFMapCreated: (controller) {
              ctl = controller;

              // 定位自己
              ctl?.showUserLocation(true);
              // 开始定位
              startLocation();

              // 渲染用户添加的标注
              addMarkers(ctl).then((value) {
                markers = value;
              });
              // 标注点击回调
              ctl?.setMapClickedMarkerCallback(
                  callback: (String id, dynamic extra) {
                Map now = getClickedMarker(markers, id);
                if (deleteMarker) {
                  if (now == null) return;
                  dio.delete(locationUrl + '/' + now['_id']).then((value) {
                    ctl.removeMarker(now['marker']);
                    ctl.removeOverlay(now['bmfText'].getId());
                  }).catchError((err) {
                    Toast.show("删除失败，请重试", context, gravity: Toast.CENTER);
                  });
                } else {
                  setState(() {
                    // 显示Dialog
                    _clickedMarker = now;
                  });
                }
              });
              // 地图点击回调
              ctl?.setMapOnClickedMapBlankCallback(callback: mapClickCallback);
              ctl?.setMapOnClickedMapPoiCallback(
                  callback: (poi) => mapClickCallback(poi.pt));
            },
            mapOptions: mapOptions,
          ),
          _clickedMarker == null
              ? Container(
                  width: 0,
                  height: 0,
                )
              : LocationDialog(
                  info: _clickedMarker,
                  onClose: () {
                    setState(() {
                      _clickedMarker = null;
                    });
                  }),
        ]),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        floatingActionButton: Container(
            width: 40,
            height: 170,
            margin: EdgeInsets.fromLTRB(0, 0, 4, 100),
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "addOrClose",
                  child: Tooltip(
                      message: addMarker ? "取消添加模式" : "启动添加模式，点击地图添加标注",
                      child: Icon(
                        addMarker ? Icons.close : Icons.add,
                        size: 30,
                      )),
                  elevation: 5, //阴影
                  onPressed: deleteMarker
                      ? null
                      : () {
                          setState(() {
                            addMarker = !addMarker;
                          });
                        },
                ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  heroTag: "deleteOrClose",
                  child: Tooltip(
                    message: deleteMarker ? '取消删除模式' : '启动删除模式，点击标注进行删除',
                    child: Icon(
                      deleteMarker ? Icons.close : Icons.delete,
                      size: 30,
                    ),
                  ),
                  elevation: 5, //阴影
                  onPressed: addMarker
                      ? null
                      : () {
                          setState(() {
                            deleteMarker = !deleteMarker;
                          });
                        },
                ),
                FloatingActionButton(
                  heroTag: "locateMyself",
                  child: Tooltip(
                    message: "定位到自己",
                    child: Icon(
                      Icons.my_location_sharp,
                      size: 25,
                    ),
                  ),
                  elevation: 5, //阴影
                  onPressed: () {
                    double lat = myLocate['latitude'];
                    double lng = myLocate['longitude'];
                    ctl.setCenterCoordinate(BMFCoordinate(lat, lng), true);
                    ctl.setZoomTo(18);
                  },
                ),
              ],
            )));
  }

  void mapClickCallback(BMFCoordinate coordinate) {
    print(coordinate.latitude);
    print(coordinate.longitude);
    if (addMarker) {
      Navigator.pushNamed(context, '/form',
              arguments: MarkerArguments(ctl, coordinate.latitude.toString(),
                  coordinate.longitude.toString()))
          .then((marker) {
        markers.add(marker);
      });
    }
  }
}
