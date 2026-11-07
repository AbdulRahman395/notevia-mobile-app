import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import '../services/image_compression_service.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';
import '../ui/nv.dart';
import 'account_page.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfilePage({super.key, required this.profileData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  DateTime? _dob;
  File? _newPicture;
  bool _compressing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.profileData['full_name'] ?? '').toString();
    _bioController.text = (widget.profileData['bio'] ?? '').toString();
    _dob = DateTime.tryParse((widget.profileData['date_of_birth'] ?? '').toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  Future<void> _pickPicture() async {
    try {
      final image = await AppLockService().runExcused(
        () => ImagePicker().pickImage(source: ImageSource.gallery),
      );
      if (image == null || !mounted) return;
      setState(() => _compressing = true);
      final compressed = await ImageCompressionService.compressImage(File(image.path));
      if (!mounted) return;
      setState(() {
        _compressing = false;
        if (compressed != null) _newPicture = compressed;
      });
      if (compressed == null) ToasterService.showError(context, 'That photo couldn’t be used. Try another one.');
    } catch (_) {
      if (mounted) {
        setState(() => _compressing = false);
        ToasterService.showError(context, 'Couldn’t open your photos.');
      }
    }
  }

  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendar,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final token = await TokenService.getCurrentToken();
      final name = _nameController.text.trim();
      final bio = _bioController.text.trim();
      final result = await ApiService.updateProfile(
        token,
        fullName: name.isEmpty ? null : name,
        dateOfBirth: _dob == null
            ? null
            : '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
        bio: bio.isEmpty ? null : bio,
        profilePicture: _newPicture,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ToasterService.showSuccess(context, 'Profile saved');
        Navigator.of(context).pop(true);
      } else {
        if (result['is_file_too_large'] == true) setState(() => _newPicture = null);
        ToasterService.showError(context, (result['message'] ?? 'Couldn’t save your profile').toString());
      }
    } catch (_) {
      if (mounted) ToasterService.showError(context, 'Couldn’t reach Notevia. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        shape: Border(bottom: BorderSide(color: c.lineMuted)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: NvSpace.sm),
            child: NvButton(label: 'Save', loading: _saving, onPressed: _compressing ? null : _save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(NvSpace.gutter, NvSpace.lg, NvSpace.gutter, NvSpace.xxl),
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    NvAvatar(
                      url: (widget.profileData['profile_picture'] ?? '').toString(),
                      name: _nameController.text,
                      size: 72,
                      file: _newPicture == null ? null : FileImage(_newPicture!),
                    ),
                    if (_compressing)
                      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(width: NvSpace.md),
                NvButton.secondary(
                  label: 'Change photo',
                  icon: Icons.photo_camera_outlined,
                  onPressed: _compressing ? null : _pickPicture,
                ),
              ],
            ),
            const SizedBox(height: NvSpace.lg),
            NvField(
              label: 'Full name',
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: NvSpace.md),
            Text('Date of birth', style: NvText.label.copyWith(color: c.fg)),
            const SizedBox(height: 6),
            Material(
              color: c.inset,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NvRadius.control),
                side: BorderSide(color: c.line),
              ),
              child: InkWell(
                onTap: _pickDob,
                customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NvRadius.control)),
                child: SizedBox(
                  height: NvSize.controlLg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dob == null ? 'Not set' : '${_months[_dob!.month - 1]} ${_dob!.day}, ${_dob!.year}',
                            style: NvText.body.copyWith(color: _dob == null ? c.subtle : c.fg),
                          ),
                        ),
                        Icon(Icons.calendar_today_outlined, size: 18, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: NvSpace.md),
            NvField(
              label: 'Bio',
              controller: _bioController,
              hint: 'A line or two about you',
              textCapitalization: TextCapitalization.sentences,
              maxLines: 5,
              minLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
