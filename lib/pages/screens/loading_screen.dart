import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' as scheduler;
import 'package:flutter/services.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:android_intent/android_intent.dart';

import 'package:MyNews/scoped-models/main.dart';

import 'package:MyNews/services/custom_services.dart';
import 'package:MyNews/services/db_service.dart';
import 'package:MyNews/services/notifications_service.dart';
//import 'package:MyNews/services/admob_service.dart';

class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();

  final MainModel _model;

  LoadingScreen(this._model);
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  AnimationController _logoAnimationController;
  Animation _logoAnimation;
  bool _isDialogOpen = false;

  @override
  void initState() {
    // set the logo animation controller
    _logoAnimationController = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 700),
        reverseDuration: Duration(milliseconds: 700));

    // set the logo animation
    // animate between values with Tween animation
    _logoAnimation = Tween(begin: 200.0, end: 210.0).animate(CurvedAnimation(
        curve: Curves.linear, parent: _logoAnimationController));

    // add listener to the animation controller
    _logoAnimationController.addStatusListener((AnimationStatus status) {
      // when status complete animation reverse
      if (status == AnimationStatus.completed) {
        _logoAnimationController.reverse();
        // when status dismissed animation forward
      } else if (status == AnimationStatus.dismissed) {
        _logoAnimationController.forward();
      }
    });
    // forward the animation
    _logoAnimationController.forward();

    // We require the initializers to run after the loading screen is rendered
    scheduler.SchedulerBinding.instance.addPostFrameCallback((_) {
      runInitTasks();
    });

    super.initState();
  }

  // Called when this object is removed from the tree permanently.
  @override
  void dispose() {
    _logoAnimationController.dispose();
    super.dispose();
  }

  /// This method calls the initializers and once they complete redirects to main page
  Future runInitTasks() async {
    // init notifications
    Notifications.initNotifications();

    //await DBservice.deleteDB();
    // init db
    bool initDB = await DBservice.asyncInitDB();
    // close the app if failed to init db
    if (!initDB) {
      SystemNavigator.pop();
    }

    // fetch temp data from db
    await widget._model.fetchDatafromDB();

    // checks for internet connectivity
    bool connectivity = await Connectivity.internetConnectivity();
    // if connectivity is false show dialog and stops the function
    if (!connectivity) {
      _handleNoConnectivity();
      return;
    }

    // get device location / last location
    bool location = await widget._model.fetchLocation();

    if (!location) {
      _handleNoLocation();
      return;
    }
    // app data (prefs and local)
    await widget._model.initAppData();

    // init firebase admob utility
    //AdMobHelper.initialiseAdMob();

    Navigator.of(context).pushReplacementNamed('/main');
  }

  // handle no internet connection
  void _handleNoConnectivity() {
    Fluttertoast.showToast(
      msg: 'Please connect your device to wifi network or mobile data',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );

    // Invoke internetConnectivity method every 1 second
    Timer.periodic(Duration(seconds: 1), (timer) async {
      bool connectivity = await Connectivity.internetConnectivity();
      // if connectivity is true cancel timer and call runInitTasks
      if (connectivity) {
        runInitTasks();
        timer.cancel();
      }
    });
  }

  // handle no locatiom dialog
  void _handleNoLocation() {
    Fluttertoast.showToast(
      msg: 'Please enable location service',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );

    // Invoke internetConnectivity method every 1 second
    Timer.periodic(Duration(seconds: 1), (timer) async {
      bool location = await widget._model.fetchLocation();
      // if location is true cancel timer and call runInitTasks
      if (location) {
        runInitTasks();
        timer.cancel();
      } else {
        if (!_isDialogOpen) {
          if (timer.tick > 5) {
            _isDialogOpen = true;
            showNoLocationDialog();
          }
        }
      }
    });
  }

  // show no location dialog
  void showNoLocationDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0)),
            title: Text('Can\'t get your location'),
            content: Text(
                'We need your location one time only, to determine your country and show you local news'),
            actions: <Widget>[
              FlatButton(
                  child: Text(
                    'OK',
                    style: TextStyle(color: Theme.of(context).accentColor),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  }),
              FlatButton(
                  child: Text(
                    'LOCATION SETTINGS',
                    style: TextStyle(color: Theme.of(context).accentColor),
                  ),
                  onPressed: () {
                    final AndroidIntent intent = new AndroidIntent(
                      action: 'android.settings.LOCATION_SOURCE_SETTINGS',
                    );
                    intent.launch();
                    Navigator.of(context).pop();
                  })
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: InkWell(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                  color: widget._model.isDark ? Colors.black : Colors.white),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.only(top: 50),
                    child: AnimatedBuilder(
                      animation: _logoAnimationController,
                      builder: (context, child) {
                        return Image.asset(
                          'Assets/images/loading_screen_logo.png',
                          fit: BoxFit.cover,
                          height: _logoAnimation.value,
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      'Just a few seconds and we are ready to go...'
                          .toUpperCase(),
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
