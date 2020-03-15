import 'package:flutter/material.dart';
import 'package:forecast/pages/weather_animations_list.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:forecast/models/open_weather_map_api.dart';

import 'package:forecast/pages/current_weather.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  OpenWeatherMapAPI openWeatherMapAPI = OpenWeatherMapAPI(
    cityName: "Malabe,LK",
    // coordinates: {'lat': '6.9', 'lon': '75.9'},
    // zipCode: "10115",
    units: "metric",
    forecast: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: Theme.of(context).accentColor,
        actions: <Widget>[
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.search,
              color: Colors.white,
            ),
          ),
        ],
      ),
      drawer: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.transparent,
        ),
        child: Drawer(
          elevation: 0.0,
          child: Container(
            color: Colors.black.withOpacity(0.8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    UserAccountsDrawerHeader(
                      accountName: Text("Bruce Wayne"),
                      accountEmail: Text("bruce@wayne.inc"),
                      currentAccountPicture: CircleAvatar(
                        child: Text(
                          "B",
                          style: TextStyle(fontSize: 40.0),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      decoration: BoxDecoration(color: Colors.transparent),
                    ),
                    ListTile(
                      leading: Icon(
                        FontAwesome5.moon,
                        color: Colors.white70,
                      ),
                      title: Text(
                        "Switch mode",
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Switch(
                        value: false,
                        onChanged: (value) {
                          setState(() {
//                          mode = value;
                          });
                        },
                      ),
                    ),
                    ListTile(
                      onTap: () {},
                      leading: Icon(
                        FontAwesomeIcons.heart,
                        color: Colors.white70,
                      ),
                      title: Text("Favourites"),
                      trailing: Icon(
                        FontAwesomeIcons.angleRight,
                        color: Colors.white70,
                      ),
                    ),
                    ListTile(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FlareAnimationsPage(),
                          ),
                        );
                      },
                      leading: Icon(
                        FontAwesomeIcons.cloudSunRain,
                        color: Colors.white70,
                      ),
                      title: Text("Weather Animations"),
                      trailing: Icon(
                        FontAwesomeIcons.angleRight,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: <Widget>[
                    ListTile(
                      onTap: () {},
                      leading: Icon(
                        FontAwesomeIcons.cog,
                        color: Colors.white70,
                      ),
                      title: Text("Settings"),
                      trailing: Icon(
                        FontAwesomeIcons.angleRight,
                        color: Colors.white70,
                      ),
                    ),
                    ListTile(
                      onTap: () {},
                      leading: Icon(
                        FontAwesomeIcons.powerOff,
                        color: Colors.white70,
                      ),
                      title: Text("Log out"),
                      trailing: Icon(
                        FontAwesomeIcons.angleRight,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: CurrentWeatherPage(),
    );
  }
}
