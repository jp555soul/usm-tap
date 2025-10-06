import 'package:flutter/material.dart';

/// Target position form for setting HoloOcean agent destination
/// Handles coordinate input, validation, and submission
class TargetFormWidget extends StatefulWidget {
  final Function(double lat, double lon, double depth, String? time) onSetTarget;
  final bool isLoading;
  final Function(double, double, double)? validateCoordinates;
  final Function(double, double, double)? formatCoordinates;

  const TargetFormWidget({
    Key? key,
    required this.onSetTarget,
    this.isLoading = false,
    this.validateCoordinates,
    this.formatCoordinates,
  }) : super(key: key);

  @override
  State<TargetFormWidget> createState() => _TargetFormWidgetState();
}

class _TargetFormWidgetState extends State<TargetFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _depthController = TextEditingController();
  final _timeController = TextEditingController();

  final List<String> _validationErrors = [];
  final Map<String, String?> _fieldErrors = {};
  bool _showTimeInput = false;
  bool _showPresets = false;

  // Coordinate presets for common locations
  final List<CoordinatePreset> _coordinatePresets = [
    CoordinatePreset(
      name: 'Mariana Trench',
      lat: 11.35,
      lon: 142.20,
      depth: 10900,
      description: 'Deepest point on Earth',
    ),
    CoordinatePreset(
      name: 'Mid-Atlantic Ridge',
      lat: 0.0,
      lon: -25.0,
      depth: 3000,
      description: 'Mid-ocean ridge',
    ),
    CoordinatePreset(
      name: 'Gulf of Mexico',
      lat: 25.0,
      lon: -90.0,
      depth: 1500,
      description: 'Gulf waters',
    ),
    CoordinatePreset(
      name: 'Pacific Deep',
      lat: 30.0,
      lon: -140.0,
      depth: 4000,
      description: 'Deep Pacific Ocean',
    ),
    CoordinatePreset(
      name: 'Surface Test',
      lat: 0.0,
      lon: 0.0,
      depth: 0,
      description: 'Surface position',
    ),
  ];

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _depthController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _handleInputChange(String field) {
    setState(() {
      _fieldErrors[field] = null;
      _validationErrors.clear();
    });
  }

  bool _validateForm() {
    setState(() {
      _validationErrors.clear();
      _fieldErrors.clear();
    });

    final errors = <String>[];
    final fieldErrs = <String, String?>{};

    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    final depth = double.tryParse(_depthController.text);

    // Check for missing required fields
    if (_latController.text.trim().isEmpty) {
      fieldErrs['lat'] = 'Latitude is required';
      errors.add('Latitude is required');
    } else if (lat == null) {
      fieldErrs['lat'] = 'Latitude must be a number';
      errors.add('Latitude must be a valid number');
    } else if (lat < -90 || lat > 90) {
      fieldErrs['lat'] = 'Latitude must be between -90 and 90';
      errors.add('Latitude must be between -90 and 90 degrees');
    }

    if (_lonController.text.trim().isEmpty) {
      fieldErrs['lon'] = 'Longitude is required';
      errors.add('Longitude is required');
    } else if (lon == null) {
      fieldErrs['lon'] = 'Longitude must be a number';
      errors.add('Longitude must be a valid number');
    } else if (lon < -180 || lon > 180) {
      fieldErrs['lon'] = 'Longitude must be between -180 and 180';
      errors.add('Longitude must be between -180 and 180 degrees');
    }

    if (_depthController.text.trim().isEmpty) {
      fieldErrs['depth'] = 'Depth is required';
      errors.add('Depth is required');
    } else if (depth == null) {
      fieldErrs['depth'] = 'Depth must be a number';
      errors.add('Depth must be a valid number');
    }

    // Validate time if provided
    if (_timeController.text.trim().isNotEmpty) {
      try {
        DateTime.parse(_timeController.text);
      } catch (e) {
        fieldErrs['time'] = 'Invalid time format';
        errors.add('Time must be in ISO-8601 format (e.g., 2025-08-14T12:00:00Z)');
      }
    }

    // Custom validation if provided
    if (widget.validateCoordinates != null && lat != null && lon != null && depth != null) {
      // Note: Assuming validateCoordinates returns ValidationResult with isValid and errors
      // You'll need to implement this based on your actual validation logic
    }

    setState(() {
      _validationErrors.addAll(errors);
      _fieldErrors.addAll(fieldErrs);
    });

    return errors.isEmpty;
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;

    final lat = double.parse(_latController.text);
    final lon = double.parse(_lonController.text);
    final depth = double.parse(_depthController.text);
    final time = _timeController.text.trim().isEmpty ? null : _timeController.text.trim();

    try {
      await widget.onSetTarget(lat, lon, depth, time);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Target set successfully')),
        );
      }
    } catch (error) {
      setState(() {
        _validationErrors.add(error.toString());
      });
    }
  }

  void _handlePresetSelect(CoordinatePreset preset) {
    setState(() {
      _latController.text = preset.lat.toString();
      _lonController.text = preset.lon.toString();
      _depthController.text = preset.depth.toString();
      _showPresets = false;
      _validationErrors.clear();
      _fieldErrors.clear();
    });
  }

  void _setCurrentTime() {
    setState(() {
      _timeController.text = DateTime.now().toIso8601String();
    });
  }

  void _clearTime() {
    setState(() {
      _timeController.clear();
    });
  }

  void _clearForm() {
    setState(() {
      _latController.clear();
      _lonController.clear();
      _depthController.clear();
      _timeController.clear();
      _validationErrors.clear();
      _fieldErrors.clear();
    });
  }

  String? _getFormattedPreview() {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    final depth = double.tryParse(_depthController.text);

    if (lat == null || lon == null || depth == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;

    if (widget.formatCoordinates != null) {
      // Use custom formatter if provided
      return null; // Placeholder - implement based on formatter return type
    }

    return '${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°, ${depth.toStringAsFixed(1)}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade600),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Set Target Position',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showPresets = !_showPresets;
                  });
                },
                child: Text(
                  _showPresets ? 'Hide Presets' : 'Show Presets',
                  style: const TextStyle(fontSize: 14, color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Coordinate Presets
          if (_showPresets)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border.all(color: Colors.grey.shade600),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Presets',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _coordinatePresets.length,
                    itemBuilder: (context, index) {
                      final preset = _coordinatePresets[index];
                      return InkWell(
                        onTap: () => _handlePresetSelect(preset),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade700,
                            border: Border.all(color: Colors.grey.shade600),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                preset.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                preset.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade300,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${preset.lat}°, ${preset.lon}°, ${preset.depth}m',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coordinate Inputs
                Row(
                  children: [
                    // Latitude
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Latitude',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            enabled: !widget.isLoading,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'e.g., 11.35',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade700,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['lat'] != null
                                      ? Colors.red.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['lat'] != null
                                      ? Colors.red.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['lat'] != null
                                      ? Colors.red.shade400
                                      : Colors.blue.shade400,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => _handleInputChange('lat'),
                          ),
                          if (_fieldErrors['lat'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _fieldErrors['lat']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '-90 to 90 degrees',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Longitude
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Longitude',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _lonController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            enabled: !widget.isLoading,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'e.g., 142.20',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade700,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['lon'] != null
                                      ? Colors.red.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['lon'] != null
                                      ? Colors.red.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['lon'] != null
                                      ? Colors.red.shade400
                                      : Colors.blue.shade400,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => _handleInputChange('lon'),
                          ),
                          if (_fieldErrors['lon'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _fieldErrors['lon']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '-180 to 180 degrees',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Depth
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Depth',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _depthController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            enabled: !widget.isLoading,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'e.g., 10900',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade700,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['depth'] != null
                                      ? Colors.red.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['depth'] != null
                                      ? Colors.red.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _fieldErrors['depth'] != null
                                      ? Colors.red.shade400
                                      : Colors.blue.shade400,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => _handleInputChange('depth'),
                          ),
                          if (_fieldErrors['depth'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _fieldErrors['depth']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '-11000 to 11000 meters',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Time Input (Optional)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Time (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showTimeInput = !_showTimeInput;
                                });
                              },
                              child: Text(
                                _showTimeInput ? 'Hide Time Input' : 'Show Time Input',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            if (_showTimeInput) ...[
                              TextButton(
                                onPressed: _setCurrentTime,
                                child: const Text(
                                  'Use Current Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _clearTime,
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (_showTimeInput) ...[
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _timeController,
                        enabled: !widget.isLoading,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '2025-08-14T12:00:00Z',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          filled: true,
                          fillColor: Colors.grey.shade700,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _fieldErrors['time'] != null
                                  ? Colors.red.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _fieldErrors['time'] != null
                                  ? Colors.red.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _fieldErrors['time'] != null
                                  ? Colors.red.shade400
                                  : Colors.blue.shade400,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (_) => _handleInputChange('time'),
                      ),
                      if (_fieldErrors['time'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _fieldErrors['time']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'ISO-8601 format (YYYY-MM-DDTHH:mm:ssZ). Leave blank to use current time.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Coordinate Preview
                if (_getFormattedPreview() != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade900.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.blue.shade700.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Preview',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFormattedPreview()!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Validation Errors
                if (_validationErrors.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.red.shade700.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Validation Errors',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._validationErrors.map((error) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(color: Colors.red.shade400),
                                  ),
                                  Expanded(
                                    child: Text(
                                      error,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red.shade300,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),

                // Submit Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.isLoading ||
                                _latController.text.isEmpty ||
                                _lonController.text.isEmpty ||
                                _depthController.text.isEmpty
                            ? null
                            : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: widget.isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Setting Target...'),
                                ],
                              )
                            : const Text('Set Target Position'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: widget.isLoading ? null : _clearForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Help Text
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Coordinates use decimal degrees (positive = North/East, negative = South/West)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      '• Depth uses meters with positive values going deeper underwater',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      '• Time is optional and defaults to current time if not specified',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      '• The agent will navigate to this position when the target is set',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CoordinatePreset {
  final String name;
  final double lat;
  final double lon;
  final double depth;
  final String description;

  CoordinatePreset({
    required this.name,
    required this.lat,
    required this.lon,
    required this.depth,
    required this.description,
  });
}