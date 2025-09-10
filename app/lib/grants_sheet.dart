import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:share_plus/share_plus.dart';
import 'pb.dart';

class GrantsSheet extends StatefulWidget {
  final Map<String, dynamic>? lock;
  final VoidCallback onBack;
  const GrantsSheet({super.key, required this.lock, required this.onBack});

  @override
  State<GrantsSheet> createState() => _GrantsSheetState();
}

class _GrantsSheetState extends State<GrantsSheet> {
  final _pb = PB.instance;
  List<dynamic> _grants = [];
  String? _grantsError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchGrants();
  }

  Future<void> _fetchGrants() async {
    setState(() {
      _loading = true;
      _grantsError = null;
    });
    try {
      final result = await _pb.collection('doorlock_grants').getFullList(
        filter: 'lock = "${widget.lock?['id']}"',
      );
      setState(() {
        _grants = result.map((r) => r.toJson()).toList();
        _loading = false;
      });
    } on ClientException catch (e) {
      if (e.statusCode == 401) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }
      setState(() {
        _grantsError = 'Failed to load grants: $e';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _grantsError = 'Failed to load grants: $e';
        _loading = false;
      });
    }
  }

  void _showAddGrantForm(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    DateTime? notBefore = DateTime.now();
    DateTime? notAfter;
    int? usageLimit;
    String? error;
    bool submitting = false;
    String name = '';

    String formatDateTime(DateTime? dt) {
      if (dt == null) return '';
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Create Grant', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'Grant name',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                        onChanged: (val) => name = val,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Not before',
                          hintText: 'Select start date/time',
                        ),
                        controller: TextEditingController(
                          text: formatDateTime(notBefore),
                        ),
                        onTap: () async {
                          final currentContext = context;
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: currentContext,
                            initialDate: notBefore ?? now,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: now.add(const Duration(days: 365 * 10)),
                          );
                          if (picked != null && currentContext.mounted) {
                            final time = await showTimePicker(
                              context: currentContext,
                              initialTime: TimeOfDay.fromDateTime(notBefore ?? now),
                            );
                            if (time != null && currentContext.mounted) {
                              // Combine picked date and time as local, then convert to UTC for storage
                              final local = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                              setModalState(() {
                                notBefore = local;
                              });
                            }
                          }
                        },
                        validator: (_) {
                          if (notBefore == null) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Not after',
                          hintText: 'Select end date/time',
                        ),
                        controller: TextEditingController(
                          text: formatDateTime(notAfter),
                        ),
                        onTap: () async {
                          final currentContext = context;
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: currentContext,
                            initialDate: notAfter ?? now,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: now.add(const Duration(days: 365 * 10)),
                          );
                          if (picked != null && currentContext.mounted) {
                            final time = await showTimePicker(
                              context: currentContext,
                              initialTime: TimeOfDay.fromDateTime(notAfter ?? now),
                            );
                            if (time != null && currentContext.mounted) {
                              final local = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                              setModalState(() {
                                notAfter = local;
                              });
                            }
                          }
                        },
                        validator: (_) {
                          if (notAfter == null) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Usage limit (leave empty for unlimited)',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          setModalState(() {
                            usageLimit = val.isEmpty ? null : int.tryParse(val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (error != null) ...[
                        Text(error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                      ],
                      ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final currentContext = context;
                                if (!formKey.currentState!.validate()) return;
                                if (notBefore == null || notAfter == null) return;
                                setModalState(() => submitting = true);
                                try {
                                  final body = {
                                    'not_before': notBefore!.toUtc().toIso8601String(),
                                    'not_after': notAfter!.toUtc().toIso8601String(),
                                    'lock': widget.lock?['id'],
                                    'usage_limit': usageLimit ?? -1,
                                    'name': name,
                                  };
                                  await _pb.collection('doorlock_grants').create(body: body);
                                  if (currentContext.mounted) {
                                    Navigator.of(currentContext).pop();
                                    if (mounted) {
                                      await _fetchGrants();
                                    }
                                  }
                                } on ClientException catch (e) {
                                  setModalState(() {
                                    error = e.toString();
                                    submitting = false;
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    error = e.toString();
                                    submitting = false;
                                  });
                                }
                              },
                        child: submitting ? const CircularProgressIndicator() : const Text('Create'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditGrantForm(BuildContext context, Map<String, dynamic> grant) {
    final formKey = GlobalKey<FormState>();
    DateTime? notBefore = grant['not_before'] != null ? DateTime.tryParse(grant['not_before']) : null;
    DateTime? notAfter = grant['not_after'] != null ? DateTime.tryParse(grant['not_after']) : null;
    int? usageLimit = grant['usage_limit'] == -1 ? null : grant['usage_limit'];
    String? error;
    bool submitting = false;
    String name = grant['name'] ?? '';

    String formatDateTime(DateTime? dt) {
      if (dt == null) return '';
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Edit Grant', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'Grant name',
                        ),
                        initialValue: grant['name'] ?? '',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                        onChanged: (val) => name = val,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Not before',
                          hintText: 'Select start date/time',
                        ),
                        controller: TextEditingController(
                          text: formatDateTime(notBefore),
                        ),
                        onTap: () async {
                          final currentContext = context;
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: currentContext,
                            initialDate: notBefore ?? now,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: now.add(const Duration(days: 365 * 10)),
                          );
                          if (picked != null && currentContext.mounted) {
                            final time = await showTimePicker(
                              context: currentContext,
                              initialTime: TimeOfDay.fromDateTime(notBefore ?? now),
                            );
                            if (time != null && currentContext.mounted) {
                              final local = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                              setModalState(() {
                                notBefore = local;
                              });
                            }
                          }
                        },
                        validator: (_) {
                          if (notBefore == null) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Not after',
                          hintText: 'Select end date/time',
                        ),
                        controller: TextEditingController(
                          text: formatDateTime(notAfter),
                        ),
                        onTap: () async {
                          final currentContext = context;
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: currentContext,
                            initialDate: notAfter ?? now,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: now.add(const Duration(days: 365 * 10)),
                          );
                          if (picked != null && currentContext.mounted) {
                            final time = await showTimePicker(
                              context: currentContext,
                              initialTime: TimeOfDay.fromDateTime(notAfter ?? now),
                            );
                            if (time != null && currentContext.mounted) {
                              final local = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                              setModalState(() {
                                notAfter = local;
                              });
                            }
                          }
                        },
                        validator: (_) {
                          if (notAfter == null) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Usage limit (leave empty for unlimited)',
                        ),
                        initialValue: usageLimit?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          setModalState(() {
                            usageLimit = val.isEmpty ? null : int.tryParse(val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (error != null) ...[
                        Text(error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                      ],
                      ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final currentContext = context;
                                if (!formKey.currentState!.validate()) return;
                                if (notBefore == null || notAfter == null) return;
                                setModalState(() => submitting = true);
                                try {
                                  final body = {
                                    'not_before': notBefore!.toUtc().toIso8601String(),
                                    'not_after': notAfter!.toUtc().toIso8601String(),
                                    'usage_limit': usageLimit ?? -1,
                                    'name': name,
                                  };
                                  await _pb.collection('doorlock_grants').update(grant['id'], body: body);
                                  if (currentContext.mounted) {
                                    Navigator.of(currentContext).pop();
                                    if (mounted) {
                                      await _fetchGrants();
                                    }
                                  }
                                } on ClientException catch (e) {
                                  setModalState(() {
                                    error = e.toString();
                                    submitting = false;
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    error = e.toString();
                                    submitting = false;
                                  });
                                }
                              },
                        child: submitting ? const CircularProgressIndicator() : const Text('Save'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareDeeplink(BuildContext context, String deeplink) async {
    try {
      // ignore: deprecated_member_use
      await Share.share(deeplink);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: deeplink));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deeplink copied to clipboard')),
        );
      }
    }
  }

  void _deleteGrant(BuildContext context, Map<String, dynamic> grant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Grant'),
        content: Text('Are you sure you want to delete grant "${grant['name'] ?? 'Unnamed grant'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _pb.collection('doorlock_grants').delete(grant['id']);
        await _fetchGrants();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grant deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete grant: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = widget.lock;
    return Scaffold(
      appBar: AppBar(
        title: Text('Grants for ${lock?['name'] ?? lock?['entity_id'] ?? 'Unknown lock'}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Grant',
            onPressed: () => _showAddGrantForm(context),
          ),
        ],
      ),
      body: _grantsError != null
          ? Center(child: Text(_grantsError!, style: const TextStyle(color: Colors.red)))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _grants.length,
                  itemBuilder: (context, index) {
                    final grant = _grants[index];
                    final deeplink = Uri.base.replace(queryParameters: {'grant': grant['token']}).toString();
                    final notBefore = grant['not_before'] != null ? DateTime.tryParse(grant['not_before']) : null;
                    final notAfter = grant['not_after'] != null ? DateTime.tryParse(grant['not_after']) : null;
                    final usageLimit = grant['usage_limit'];
                    return ListTile(
                      title: Text(grant['name'] ?? 'Unnamed grant', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (notBefore != null)
                                Text('From: ${notBefore.toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 8),
                              if (notAfter != null)
                                Text('Until: ${notAfter.toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          if (usageLimit == -1)
                            const Text('Usage: unlimited', style: TextStyle(fontSize: 13))
                          else if (usageLimit != null)
                            Text('Usage limit: $usageLimit', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      onTap: () => _showEditGrantForm(context, grant),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share),
                            tooltip: 'Share Deeplink',
                            onPressed: () async {
                              await _shareDeeplink(context, deeplink);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete Grant',
                            onPressed: () => _deleteGrant(context, grant),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
