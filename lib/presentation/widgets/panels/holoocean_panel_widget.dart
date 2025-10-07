import 'package:flutter/material.dart';

class HoloOceanPanelWidget extends StatefulWidget {
  const HoloOceanPanelWidget({Key? key}) : super(key: key);

  @override
  State<HoloOceanPanelWidget> createState() => _HoloOceanPanelWidgetState();
}

class _HoloOceanPanelWidgetState extends State<HoloOceanPanelWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Center(
        child: Text(
          'HoloOcean Panel',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}