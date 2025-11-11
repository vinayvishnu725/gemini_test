import 'package:flutter_gemini/flutter_gemini.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

// const apiKey = 'AIzaSyCxwTSFA-1MmJK6p4ptUxOAEdTFEmxF5UA';
// void main() {
//   Gemini.init(apiKey: apiKey, enableDebugging: true);

//   Gemini.instance.prompt(parts: [
//     Part.text('what is your name '),
//   ]).then((value) {
//     print(value?.output);
//   });
// }

// ⚠️ Replace with your actual API Key
const String apiKey = 'AIzaSyCxwTSFA-1MmJK6p4ptUxOAEdTFEmxF5UA';

void main() {
  if (apiKey == 'AIzaSyCxwTSFA-1MmJK6p4ptUxOAEdTFEmxF5UA') {
    print('start ...');
  }

  Gemini.init(apiKey: apiKey, enableDebugging: true);
  runApp(const GeminiChatApp());
}

// --- 1. Message Model ---
class ChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBytes;

  ChatMessage({required this.text, required this.isUser, this.imageBytes});
}

// --- 2. Main App and Chat Screen ---

class GeminiChatApp extends StatelessWidget {
  const GeminiChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Chat App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  Uint8List? _selectedImageBytes; // Stores the bytes of the selected image

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- 3. Image Picking Logic ---
 // --- 3. Image Picking Logic ---
Future<void> _pickImage() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    // FIX: Add withData: true to ensure bytes are loaded into memory
    withData: true, 
  );

  if (result != null && result.files.single.bytes != null) {
    setState(() {
      _selectedImageBytes = result.files.single.bytes;
      // Optionally, pre-fill the text field with a placeholder
      if (_controller.text.isEmpty) {
        _controller.text = 'Describe this image.';
      }
    });
  }
}

  void _clearImage() {
    setState(() {
      _selectedImageBytes = null;
      if (_controller.text == 'Describe this image.') {
        _controller.clear();
      }
    });
  }

  // --- 4. Gemini API Integration (Multimodal) ---
  // --- 4. Gemini API Integration (Multimodal) ---
  void _sendPrompt() async {
    final text = _controller.text.trim();
    final imageBytes = _selectedImageBytes;

    if (text.isEmpty && imageBytes == null) return;

    // Add user message to the list
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        imageBytes: imageBytes,
      ));
      _isLoading = true;
      _controller.clear();
      _selectedImageBytes = null; // Clear image after sending
    });

    // Auto-scroll to the bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    try {
      final gemini = Gemini.instance;
      
      // FIX HERE: Use an empty list [] instead of null when no image is selected.
      final response = await gemini.textAndImage(
        text: text,
        images: imageBytes != null ? [imageBytes] : [],
      );

      // Add AI response to the list
      setState(() {
        _messages.add(ChatMessage(
          // Use 'output' property for the response text
          text: response?.output ?? 'Error: No response from Gemini.',
          isUser: false,
        ));
      });
    } catch (e) {
      // Handle errors (e.g., API key, network issues)
      if (kDebugMode) {
        print('Gemini Error: $e');
      }
      setState(() {
        _messages.add(ChatMessage(
          text: 'Error: Failed to get response. Check your API key or network.',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      // Auto-scroll to the bottom again
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }
  // --- 5. UI Builder (Message Bubble) ---
  Widget _buildMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.circular(16.0).copyWith(
            topRight: message.isUser
                ? const Radius.circular(0)
                : const Radius.circular(16.0),
            topLeft: message.isUser
                ? const Radius.circular(16.0)
                : const Radius.circular(0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.memory(
                  message.imageBytes!,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8.0),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. Main Widget Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Chat App by Vinay Codecraft'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  return _buildMessage(_messages[index]);
                }
                // Loading indicator for the AI's response
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),

          // Image Preview (if selected)
          if (_selectedImageBytes != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.memory(
                      _selectedImageBytes!,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _clearImage,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white70,
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Input Field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                // Image Picker Button
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _isLoading ? null : _pickImage,
                  color: Colors.blueAccent,
                ),

                // Text Input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Send a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                    ),
                    onSubmitted: _isLoading ? null : (_) => _sendPrompt(),
                  ),
                ),

                // Send Button
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendPrompt,
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
