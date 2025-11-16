import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NameInputDialog extends StatefulWidget {
  const NameInputDialog({super.key});

  @override
  State<NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<NameInputDialog> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    
    if (mounted) {
      Navigator.pop(context, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5B67CA),
                    const Color(0xFF9B8CE8),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 40,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'What would you like to be called?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D2E),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              'This name will be used to personalize your experience',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF718096),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                prefixIcon: const Icon(Icons.person),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5B67CA), width: 2),
                ),
              ),
              onSubmitted: (_) => _saveName(),
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B67CA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}