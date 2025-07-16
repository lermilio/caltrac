import 'package:flutter/material.dart';
import 'package:caltrac/widgets/remove_entry_widget.dart';

class WeightScreen extends StatefulWidget{
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
final TextEditingController _controllerWeight = TextEditingController();
final TextEditingController _controllerDate = TextEditingController();
  String _userWeight = '';
  String _userDate = '';

  void _submitInput() {
    setState(() {
      _userWeight = _controllerWeight.text;
      _userDate = _controllerDate.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Center(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => RemoveEntryWidget(),
                  );
                },
                child: Text(
                  'View entries',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                            ),
              ),
            ),
            SizedBox(
              height: 100
            ),
            Text(
              'Enter Weight (lbs):',
              style: TextStyle(
                fontSize: 25
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: TextField(
                controller: _controllerWeight,
                decoration: InputDecoration(
                  labelText: 'e.g "163"',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    fontSize: 10
                  )
                ),
              ),
            ),
            Text(
              'Enter date:',
              style: TextStyle(
                fontSize: 25
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: TextField(
                controller: _controllerDate,
                decoration: InputDecoration(
                  labelText: 'e.g "04/27/2005"',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    fontSize: 10
                  )
                ),
              ),
            ),
            FloatingActionButton.extended(
              onPressed: () { _submitInput(); },
              backgroundColor: Colors.blue[300],
              label: Text(
                '          Add          ',
              ),
            ),
            SizedBox(
              height: 10,
            ),
          ],
        ),
      )
    );
  }
}