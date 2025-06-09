import 'package:flutter/material.dart';

class AddHomeAssistantPage extends StatefulWidget {
  final Future<void> Function(String url, String frontendCallback) onSubmit;
  final String? error;
  const AddHomeAssistantPage({super.key, required this.onSubmit, this.error});

  @override
  State<AddHomeAssistantPage> createState() => _AddHomeAssistantPageState();
}

class _AddHomeAssistantPageState extends State<AddHomeAssistantPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; });
    await widget.onSubmit(_urlController.text.trim(), _getFrontendCallback());
    setState(() { _submitting = false; });
  }

  String _getFrontendCallback() {
    // For web, use current URL as callback
    // For mobile, you may want to use a custom scheme or deep link
    return Uri.base.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Home Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.error != null) ...[
                Text(widget.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'Home Assistant Base URL'),
                validator: (v) => v == null || v.isEmpty ? 'Enter the base URL' : null,
                enabled: !_submitting,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const CircularProgressIndicator() : const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
