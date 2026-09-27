import 'package:flutter/material.dart';
import '../core/records.dart';
import '../core/store.dart';
import 'theme.dart';

/// Local contacts only. There is no remote invitation or account lookup.
class CareCirclePage extends StatelessWidget {
  final AppStore store;
  const CareCirclePage({super.key, required this.store});

  Future<void> edit(BuildContext context, {Json? existing, int? index}) async {
    final name = TextEditingController(text: existing?['name'] as String? ?? '');
    final phone = TextEditingController(text: existing?['phone'] as String? ?? '');
    final relation = TextEditingController(
        text: existing?['relationship'] as String? ?? '');
    final form = GlobalKey<FormState>();
    final result = await showDialog<Json>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(index == null ? 'Add care contact' : 'Edit care contact'),
        content: Form(
          key: form,
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: relation,
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
            ],
          )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, {
                  ...?existing,
                  'name': name.text.trim(),
                  'phone': phone.text.trim(),
                  'relationship': relation.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
    relation.dispose();
    if (result == null) return;
    try {
      await store.update((r) {
        final contacts = r.data['careContacts'] as List;
        if (index == null) {
          contacts.add(result);
        } else {
          contacts[index] = result;
        }
      });
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> remove(BuildContext context, int index) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove care contact?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await store.update((r) => (r.data['careContacts'] as List).removeAt(index));
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final contacts = (store.data['careContacts'] as List? ?? []).cast<Json>();
      return Scaffold(
        appBar: AppBar(title: const Text('Care Circle')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: store.busy ? null : () => edit(context),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Add contact'),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Keep trusted contacts here. This list stays on your device. '
              'Adding someone does not give them access to your records or send an invitation.',
              style: TextStyle(height: 1.4, color: deepInk),
            ),
          ),
          const SizedBox(height: 18),
          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No care contacts yet.', textAlign: TextAlign.center),
            ),
          for (var i = 0; i < contacts.length; i++)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEEFFF),
                  child: Icon(Icons.person_outline, color: ink),
                ),
                title: Text(contacts[i]['name'] as String? ?? 'Contact'),
                subtitle: Text([
                  if ((contacts[i]['relationship'] as String? ?? '').isNotEmpty)
                    contacts[i]['relationship'] as String,
                  if ((contacts[i]['phone'] as String? ?? '').isNotEmpty)
                    contacts[i]['phone'] as String,
                ].join(' · ')),
                onTap: store.busy ? null : () => edit(context, existing: contacts[i], index: i),
                trailing: IconButton(
                  tooltip: 'Remove contact',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: store.busy ? null : () => remove(context, i),
                ),
              ),
            ),
        ]),
      );
    },
  );
}
