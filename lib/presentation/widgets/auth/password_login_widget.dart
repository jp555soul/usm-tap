import 'package:flutter/material.dart';

class PasswordLoginWidget extends StatefulWidget {
  final Function(String) onSubmit;
  final String? errorMessage;
  final bool isLoading;

  const PasswordLoginWidget({
    Key? key,
    required this.onSubmit,
    this.errorMessage,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<PasswordLoginWidget> createState() => _PasswordLoginWidgetState();
}

class _PasswordLoginWidgetState extends State<PasswordLoginWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!widget.isLoading) {
      widget.onSubmit(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          obscureText: true,
          autofocus: true,
          enabled: !widget.isLoading,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter password',
            hintStyle: const TextStyle(color: Color(0xFF64748B)), // slate-500
            filled: true,
            fillColor: const Color(0xFF334155), // slate-700
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF475569)), // slate-600
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF475569)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2), // pink-500
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF475569)),
            ),
          ),
          onSubmitted: (_) => _handleSubmit(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDB2777), // pink-600
              disabledBackgroundColor: const Color(0xFFF472B6), // pink-400
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: widget.isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Unlocking...',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : const Text(
                    'Unlock',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.errorMessage!,
            style: const TextStyle(color: Color(0xFFF87171), fontSize: 14), // red-400
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
