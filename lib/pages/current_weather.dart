import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:forecast/pages/weather_forecast.dart';
import 'package:forecast/utils/common/constants.dart';
import 'package:forecast/widgets/error/no_internet.dart';
import 'package:forecast/utils/animations/FadeAnimation.dart';
import 'package:forecast/utils/common/common_utils.dart';
import 'package:forecast/utils/common/shared_preferences.dart';
import 'package:forecast/utils/themes/app_theme.dart';
import 'package:forecast/utils/themes/themes.dart';
import 'package:intl/intl.dart';

import 'package:forecast/models/openweathermap_api.dart';
import 'package:forecast/widgets/current_weather/card_data.dart';
import 'package:forecast/widgets/current_weather/temp_data_card.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:forecast/blocs/current_weather_bloc.dart';
import 'package:forecast/models/weather_model.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';

class CurrentWeatherDetailsPage extends StatefulWidget {
  final String cityName;

  CurrentWeatherDetailsPage({Key key, this.cityName}) : super(key: key);

  @override
  _CurrentWeatherDetailsPageState createState() =>
      _CurrentWeatherDetailsPageState();
}

class _CurrentWeatherDetailsPageState extends State<CurrentWeatherDetailsPage> {
  bool hasInternet = true;
  OpenWeatherMapAPI openWeatherMapAPI;
  Geolocator geolocator = Geolocator();
  Position userLocation;
  DateTime locationDate;
  String cityName;
  String country;
  bool isSaved = false;
  String userId;
  String units;
  String temperatureUnit;

  List savedLocations;
  DocumentReference documentReference;

  ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    checkInternet();
    _getUserId();
    _getLocation().then((position) async {
      userLocation = position;
      print(userLocation);

      if (widget.cityName == null && userLocation != null) {
        await _getLocationAddress(userLocation).then((address) {
          print(address[0].toJson());
          print("LOCALITY: " + (address[0].locality != "").toString());

          if (address[0].locality != "") {
            setState(() {
              this.cityName =
                  "${address[0].locality},${address[0].isoCountryCode}";
              print(this.cityName);
              openWeatherMapAPI = OpenWeatherMapAPI(
                cityName: this.cityName,
                units: units,
              );
            });
          } else {
            setState(() {
              openWeatherMapAPI = OpenWeatherMapAPI(
                coordinates: {
                  'lat': userLocation.latitude,
                  'lon': userLocation.longitude
                },
                units: units,
              );
            });
          }
        });
      } else {
        setState(() {
          this.cityName = widget.cityName;
          print(this.cityName);
        });
        openWeatherMapAPI = OpenWeatherMapAPI(
          cityName: this.cityName,
          units: units,
        );
      }
      _checkSavedLocations();
      currentWeatherBloc.fetchCurrentWeather(openWeatherMapAPI.requestURL);
    });

    AppSharedPreferences.getStringSharedPreferences("units").then((value) {
      setState(() {
        temperatureUnit = CommonUtils.getTemperatureUnit(value);
        units = value;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
    currentWeatherBloc.dispose();
  }

  void checkInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('connected');
        setState(() {
          hasInternet = true;
        });
      }
    } on SocketException catch (_) {
      print('not connected');
      setState(() {
        hasInternet = false;
      });
    }
  }

  Future<Position> _getLocation() async {
    var currentLocation;

    try {
      currentLocation = await geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      currentLocation = null;
    }

    return currentLocation;
  }

  Future<List<Placemark>> _getLocationAddress(Position userLocation) async {
    var latitude = userLocation.latitude;
    var longitude = userLocation.longitude;

    List<Placemark> placemark = await Geolocator().placemarkFromCoordinates(
      latitude,
      longitude,
    );

    return placemark;
  }

  String _getTodayDate(int timeZone) {
    DateTime today = DateTime.now();

    if (timeZone >= 0) {
      this.locationDate = today
          .add(
            Duration(
              hours: DateFormat("ss").parse(timeZone.toString(), true).hour,
              minutes: DateFormat("ss").parse(timeZone.toString(), true).minute,
            ),
          )
          .toUtc();
    } else {
      timeZone *= -1;
      this.locationDate = today
          .subtract(
            Duration(
              hours: DateFormat("ss").parse(timeZone.toString(), true).hour,
              minutes: DateFormat("ss").parse(timeZone.toString(), true).minute,
            ),
          )
          .toUtc();
    }

    return DateFormat.yMMMMEEEEd().format(this.locationDate);
  }

  String _getTime(int seconds, int timeZone) {
    String time;
    DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toUtc();

    if (timeZone >= 0) {
      dateTime = dateTime.add(
        Duration(
          hours: DateFormat("ss").parse(timeZone.toString()).hour,
          minutes: DateFormat("ss").parse(timeZone.toString()).minute,
        ),
      );
    } else {
      timeZone *= -1;
      dateTime = dateTime.subtract(
        Duration(
          hours: DateFormat("ss").parse(timeZone.toString()).hour,
          minutes: DateFormat("ss").parse(timeZone.toString()).minute,
        ),
      );
    }

    time = DateFormat.jm().format(dateTime);
    return time.toString();
  }

  void _onAfterBuild(BuildContext context) {
    setState(() {
      if (this.locationDate != null)
        AppTheme.instanceOf(context).changeTheme(
          AppThemes.getThemeKeyFromTime(this.locationDate),
        );
    });
  }

  void _getUserId() async {
    final FirebaseUser user = await FirebaseAuth.instance.currentUser();
    setState(() {
      if (user != null) {
        this.userId = user.uid;
      }
    });
  }

  void _checkSavedLocations() {
    if (this.userId != null) {
      Firestore.instance
          .collection(usersCollection)
          .document(this.userId)
          .snapshots()
          .listen((DocumentSnapshot documentSnapshot) {
        Map<String, dynamic> documentData = documentSnapshot.data;
        if (this.mounted) {
          setState(() {
            savedLocations = documentData[userSavedLocations];
            if (savedLocations != null && savedLocations.isNotEmpty) {
              if (!this.cityName.contains(",")) {
                this.cityName = "$cityName,${this.country}";
              }
              isSaved = savedLocations.contains(this.cityName);
            } else {
              isSaved = false;
            }
            print(savedLocations);
          });
        }
      });
    }
  }

  void _handleSave(bool isSaved, String cityName) async {
    print(savedLocations);
    print(this.cityName);
    print("USERID: " + this.userId.toString());

    if (userId == null) {
      _showFlutterToast("You need to be logged in");
      return;
    }

    if (!cityName.contains(",")) {
      cityName = "$cityName,${this.country}";
    }

    this.documentReference =
        Firestore.instance.collection(usersCollection).document(this.userId);

    if (isSaved) {
      this.documentReference.updateData({
        userSavedLocations: FieldValue.arrayRemove([cityName])
      });
      setState(() {
        this.isSaved = false;
      });
      _showFlutterToast("Location removed");
    } else {
      this.documentReference.updateData({
        userSavedLocations: FieldValue.arrayUnion([cityName])
      });
      setState(() {
        this.isSaved = true;
      });
      _showFlutterToast("Location saved");
    }
  }

  void _showFlutterToast(String message) {
    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.black87,
      toastLength: Toast.LENGTH_SHORT,
      textColor: Colors.white,
    );
  }

  Widget _buildCurrentWeatherData(WeatherModel currentWeather) {
    Color _cardColor = Colors.black.withAlpha(20);

    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (scroll) {
        scroll.disallowGlow();
        return true;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ListView(
          controller: _controller,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Container(
                  height: MediaQuery.of(context).size.height * 0.685,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      FadeAnimation(
                        delay: 0.5,
                        child: Column(
                          children: <Widget>[
                            Text(
                              _getTodayDate(currentWeather.timeZone),
                              style: TitleTextStyle.apply(
                                  letterSpacingFactor: 1.2),
                            ),
                            Text(
                              currentWeather.name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: HeadingTextStyle.apply(
                                heightFactor: 1.2,
                                letterSpacingFactor: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10.0),
                      FadeAnimation(
                        delay: 0.8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Column(
                              children: <Widget>[
                                Container(
                                  height:
                                      MediaQuery.of(context).size.width * 0.4,
                                  width:
                                      MediaQuery.of(context).size.width * 0.4,
                                  child: FlareActor(
                                    "assets/flare_animations/weather_icons/weather_${currentWeather.weatherIcon}.flr",
                                    fit: BoxFit.contain,
                                    animation: currentWeather.weatherIcon,
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        currentWeather.temp,
                                        style: MainTextStyle.apply(
                                          fontSizeFactor: 1.1,
                                          heightFactor: 0.5,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4.0,
                                        ),
                                        child: Text(
                                          temperatureUnit,
                                          style: TextStyle(
                                            fontSize: 22.0,
                                            height: 0.0,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 10.0,
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 15.0,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Text(
                                          currentWeather.weatherDescription
                                              .toUpperCase(),
                                          textAlign: TextAlign.right,
                                          style: RegularTextStyle,
                                        ),
                                        SizedBox(
                                          height: 15.0,
                                        ),
                                        Text(
                                          "FEELS  ${currentWeather.feelsLike} $temperatureUnit",
                                          style: RegularTextStyle.apply(
                                            fontSizeFactor: 0.85,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 5.0,
                        ),
                        child: FadeAnimation(
                          delay: 1.2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 3.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        Icon(
                                          FontAwesomeIcons.clock,
                                          color: Colors.white70,
                                        ),
                                        SizedBox(width: 10.0),
                                        Text(
                                          "${_getTime(((locationDate.millisecondsSinceEpoch) / 1000).round(), 0)}",
                                          style: MediumTextStyle,
                                        ),
                                      ],
                                    ),
                                  )),
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _handleSave(isSaved, this.cityName);
                                        });
                                      },
                                      child: Container(
                                        child: isSaved
                                            ? Icon(
                                                Icons.favorite,
                                                color: Colors.redAccent,
                                                size: 35.0,
                                              )
                                            : Icon(
                                                Icons.favorite_border,
                                                color: Colors.white30,
                                                size: 35.0,
                                              ),
                                      ),
                                    ),
                                    SizedBox(width: 10.0),
                                    Container(
                                      height: 40.0,
                                      child: FadeInImage.assetNetwork(
                                        placeholder:
                                            "assets/images/flag-loading.png",
                                        image:
                                            "https://www.countryflags.io/${this.country}/flat/64.png",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      FadeAnimation(
                        delay: 1.4,
                        child: Row(
                          children: <Widget>[
                            TempDataCard(
                              cardColor: _cardColor,
                              cardData: CardData(
                                topElement: Icon(
                                  FontAwesomeIcons.thermometerFull,
                                  color: Colors.white,
                                  size: 24.0,
                                ),
                                middleElement: Text(
                                  "${currentWeather.tempMax}$temperatureUnit",
                                  style: RegularTextStyle,
                                ),
                                bottomElement: Text(
                                  "Max. Temp",
                                  textAlign: TextAlign.center,
                                  style: SmallTextStyle,
                                ),
                              ),
                            ),
                            TempDataCard(
                              cardColor: _cardColor,
                              cardData: CardData(
                                topElement: Icon(
                                  FontAwesomeIcons.thermometerQuarter,
                                  color: Colors.white,
                                  size: 24.0,
                                ),
                                middleElement: Text(
                                  "${currentWeather.tempMin}$temperatureUnit",
                                  style: RegularTextStyle,
                                ),
                                bottomElement: Text(
                                  "Min. Temp",
                                  textAlign: TextAlign.center,
                                  style: SmallTextStyle,
                                ),
                              ),
                            ),
                            TempDataCard(
                              cardColor: _cardColor,
                              cardData: CardData(
                                topElement: Icon(
                                  FontAwesome.tachometer,
                                  color: Colors.white,
                                  size: 24.0,
                                ),
                                middleElement: Text(
                                  "${currentWeather.pressure}hPa",
                                  style: RegularTextStyle,
                                ),
                                bottomElement: Text(
                                  "Pressure",
                                  textAlign: TextAlign.center,
                                  style: SmallTextStyle,
                                ),
                              ),
                            ),
                            TempDataCard(
                              cardColor: _cardColor,
                              cardData: CardData(
                                topElement: Icon(
                                  Entypo.drop,
                                  color: Colors.white,
                                  size: 24.0,
                                ),
                                middleElement: Text(
                                  "${currentWeather.humidity}%",
                                  style: RegularTextStyle,
                                ),
                                bottomElement: Text(
                                  "Humidity",
                                  textAlign: TextAlign.center,
                                  style: SmallTextStyle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FadeAnimation(
                        delay: 1.4,
                        child: Card(
                          elevation: 0.3,
                          color: _cardColor,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Feather.sunrise,
                                      color: Colors.white,
                                      size: 18.0,
                                    ),
                                    SizedBox(width: 15.0),
                                    Text(
                                      _getTime(
                                        currentWeather.sunRise,
                                        currentWeather.timeZone,
                                      ),
                                      style: SmallTextStyle.apply(
                                        heightFactor: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      FontAwesomeIcons.cloud,
                                      color: Colors.white,
                                      size: 15.0,
                                    ),
                                    SizedBox(width: 15.0),
                                    Text(
                                      "${currentWeather.clouds}%",
                                      style: SmallTextStyle.apply(
                                        heightFactor: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      FontAwesomeIcons.wind,
                                      color: Colors.white,
                                      size: 15.0,
                                    ),
                                    SizedBox(width: 15.0),
                                    Text(
                                      "${currentWeather.windSpeed} m/s",
                                      style: SmallTextStyle.apply(
                                        heightFactor: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Feather.sunset,
                                      color: Colors.white,
                                      size: 18.0,
                                    ),
                                    SizedBox(width: 15.0),
                                    Text(
                                      _getTime(
                                        currentWeather.sunSet,
                                        currentWeather.timeZone,
                                      ),
                                      style: SmallTextStyle.apply(
                                        heightFactor: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ////////////////// END OF OTHER DATA /////////////////////
                // TODAY'S FORECAST DETAILS //
                FadeAnimation(
                  delay: 1.6,
                  child: WeatherForecastPage(
                    controller: _controller,
                    cityName: this.cityName,
                    units: this.units,
                    temperatureUnit: this.temperatureUnit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAfterBuild(context));
    return StreamBuilder(
        stream: currentWeatherBloc.currentWeather,
        builder: (context, AsyncSnapshot<WeatherModel> snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data.cod == "200") {
              if (this.cityName == null) {
                this.cityName = snapshot.data.name;
              }
              this.country = snapshot.data.country;
              return GestureDetector(
                onDoubleTap: () {
                  String details = this.cityName;
                  _handleSave(isSaved, details);
                },
                child: _buildCurrentWeatherData(snapshot.data),
              );
            } else {
              return Center(
                child: Text(snapshot.data.error.toUpperCase()),
              );
            }
          } else if (snapshot.hasError) {
            Fluttertoast.showToast(msg: snapshot.error);
            return Center(child: Text(snapshot.error));
          } else {
            if (hasInternet) {
              return Center(
                child: CircularProgressIndicator(
                  backgroundColor: Colors.white,
                ),
              );
            } else {
              return NoInternetPage();
            }
          }
        });
  }
}
