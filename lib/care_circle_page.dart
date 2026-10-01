import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'widgets/dosebuddy_theme.dart';

/// An invitation screen. Dose data remains private until cloud sync and its
/// per-document access rules have been implemented and verified.
class CareCirclePage extends StatefulWidget {
  const CareCirclePage({super.key});

  @override
  State<CareCirclePage> createState() => _CareCirclePageState();
}

class _CareCirclePageState extends State<CareCirclePage> {
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _verificationId;
  bool _busy = false;
  final Set<String> _permissions = {'routine'};

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-east1');
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _call(String name, Map<String, dynamic> data) async {
    setState(() => _busy = true);
    try {
      await _functions.httpsCallable(name).call(data);
      if (mounted) {
        _contact.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Care Circle updated.')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _message(error.message ?? 'Could not update Care Circle.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _verifyPhone() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      _message('Enter your number with country code, for example +14045550123.');
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
            if (mounted) _message('Your phone is verified.');
          } on FirebaseAuthException catch (error) {
            if (mounted) _message(error.message ?? 'Could not link your number.');
          }
        },
        verificationFailed: (error) {
          if (mounted) _message(error.message ?? 'Could not send a code.');
        },
        codeSent: (id, token) {
          if (mounted) {
            setState(() => _verificationId = id);
            _message('Enter the text message code below.');
          }
        },
        codeAutoRetrievalTimeout: (id) {},
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) _message(error.message ?? 'Could not verify this number.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPhone() async {
    if (_verificationId == null) return;
    try {
      final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: _code.text.trim());
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
      if (mounted) {
        setState(() => _verificationId = null);
        _message('Your phone is verified.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _message(error.message ?? 'Could not verify the code.');
    }
  }

  void _preview(List<dynamic> permissions) {
    showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Permission preview'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('These are the requested permissions. Connected medication sharing is not enabled in this beta.'),const SizedBox(height:12),for(final p in permissions)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.check_circle_outline,color:DoseBuddyTheme.purple),title:Text(p=='routine'?'Routine':p=='history'?'Dose history':'Missed-dose alerts')),const Text('Symptom records and photos are not included.')]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]));
  }
  Widget _invitations({required bool sent}) {
    final query = FirebaseFirestore.instance.collection('careInvitations')
        .where(sent ? 'ownerUid' : 'recipientUid', isEqualTo: _uid);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Card(child:ListTile(leading:Icon(Icons.cloud_off_outlined),title:Text('Invitations are unavailable'),subtitle:Text('Check your connection. Backend deployment and App Check setup are required for this beta.')));
        if (!snapshot.hasData) return const LinearProgressIndicator();
        if (snapshot.data!.docs.isEmpty) return const Card(child:ListTile(leading:Icon(Icons.people_outline),title:Text('No invitations yet'),subtitle:Text('Invite a family member, or ask them to invite your verified account.')));
        return Column(children: [
          for (final doc in snapshot.data!.docs)
            Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor:DoseBuddyTheme.tint,child:Icon(Icons.person_outline,color:DoseBuddyTheme.purple)),
              onTap:()=>_preview(doc.data()['permissions'] as List<dynamic>? ?? []),
              title: Text(sent ? doc.data()['contact'] as String? ?? 'Invitation' :
                  'Invitation from another DoseBuddy account'),
              subtitle: Text('${doc.data()['status']} · ${
                (doc.data()['permissions'] as List<dynamic>? ?? []).join(', ')}'),
              trailing: doc.data()['status'] == 'pending' && !sent
                  ? Wrap(spacing: 4, children: [
                      TextButton(onPressed: _busy ? null : () => _call(
                          'respondToCareInvite', {'invitationId': doc.id, 'accept': false}),
                          child: const Text('Decline')),
                      TextButton(onPressed: _busy ? null : () => _call(
                          'respondToCareInvite', {'invitationId': doc.id, 'accept': true}),
                          child: const Text('Accept')),
                    ])
                  : sent && ['pending', 'accepted'].contains(doc.data()['status'])
                      ? TextButton(onPressed: _busy ? null : () => _call(
                          'revokeCareInvite', {'invitationId': doc.id}),
                          child: const Text('Revoke'))
                      : null,
            )),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Care Circle')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('You choose what to share',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),
      const SizedBox(height:12),
      const Card(color:DoseBuddyTheme.tint,child:ListTile(leading:Icon(Icons.info_outline,color:DoseBuddyTheme.purple),title:Text('Invitation beta'),subtitle:Text('Medication sharing and family alerts are not enabled yet.'))),
      const Text('Invite someone with an existing verified DoseBuddy account. They must accept first.'),
      const SizedBox(height:16),
      const Text('Invite a family member',style:TextStyle(fontSize:18,fontWeight:FontWeight.w600)),
      const SizedBox(height: 16),
      TextField(controller: _contact, decoration: const InputDecoration(
        labelText: 'Their email or phone (+ country code)', border: OutlineInputBorder())),
      CheckboxListTile(title: const Text('View routine'), value: _permissions.contains('routine'),
        onChanged: (v) => setState(() => v == true ? _permissions.add('routine') : _permissions.remove('routine'))),
      CheckboxListTile(title: const Text('View dose history'), value: _permissions.contains('history'),
        onChanged: (v) => setState(() => v == true ? _permissions.add('history') : _permissions.remove('history'))),
      CheckboxListTile(title: const Text('Receive missed-dose alerts'), value: _permissions.contains('missed_alerts'),
        onChanged: (v) => setState(() => v == true ? _permissions.add('missed_alerts') : _permissions.remove('missed_alerts'))),
      OutlinedButton(onPressed:()=>_preview(_permissions.toList()),child:const Text('Preview requested permissions')),
      const SizedBox(height:8),
      ElevatedButton(onPressed: _busy || _permissions.isEmpty ? null : () => _call(
        'sendCareInvite', {'contact': _contact.text.trim(), 'permissions': _permissions.toList()}),
        child: Text(_busy ? 'Updating…' : 'Send invitation')),
      const SizedBox(height: 24),
      const Text('Invitations you received', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      _invitations(sent: false),
      const SizedBox(height: 24),
      const Text('Your invitations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      _invitations(sent: true),
      const Divider(height: 40),
      const Text('Want family to find you by phone? Verify your own number first.'),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Your number (+ country code)')),
      TextButton(onPressed: _busy ? null : _verifyPhone, child: const Text('Text me a verification code')),
      if (_verificationId != null) ...[
        TextField(controller: _code, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Verification code')),
        TextButton(onPressed: _confirmPhone, child: const Text('Verify my number')),
      ],
      const SizedBox(height: 16),
      const Text('Invitations are ready to test. Medication sharing and family alerts will remain off until encrypted cloud sync and access rules are implemented.'),
    ]),
  );

  @override
  void dispose() {
    _contact.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }
}
