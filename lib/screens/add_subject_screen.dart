import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ritian_faculty/widgets/custom_navigation_drawer.dart';

class AddSubjectScreen extends StatefulWidget {
  const AddSubjectScreen({super.key});

  @override
  State<AddSubjectScreen> createState() => _AddSubjectScreenState();
}

class _AddSubjectScreenState extends State<AddSubjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectNameController = TextEditingController();
  final _subjectCodeController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  bool _showAddForm = false;
  List<Map<String, dynamic>> _subjectList = [];
  List<Map<String, dynamic>> _filteredSubjectList = [];

  @override
  void initState() {
    super.initState();
    _fetchSubjectList();
    _searchController.addListener(_filterSubjectList);
  }

  Future<void> _fetchSubjectList() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('subjects').get();
      setState(() {
        _subjectList =
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList();
        _filteredSubjectList = _subjectList;
      });
    } catch (e) {
      print('Error fetching subject list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load subject list: $e')),
      );
    }
  }

  void _filterSubjectList() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSubjectList = _subjectList;
      } else {
        _filteredSubjectList =
            _subjectList.where((subject) {
              final name =
                  subject['subject_name']?.toString().toLowerCase() ?? '';
              final code =
                  subject['subject_code']?.toString().toLowerCase() ?? '';
              return name.contains(query) || code.contains(query);
            }).toList();
      }
    });
  }

  Future<void> _addSubject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final subjectName = _subjectNameController.text.trim();
      final subjectCode = _subjectCodeController.text.trim();

      await FirebaseFirestore.instance.collection('subjects').add({
        'subject_name': subjectName,
        'subject_code': subjectCode,
        'created_at': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject added successfully')),
      );

      await _fetchSubjectList();

      _subjectNameController.clear();
      _subjectCodeController.clear();
      setState(() {
        _showAddForm = false;
      });
    } catch (e) {
      print('Error adding subject: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add subject: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Subject',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0C4D83),
        leading:
            isWeb
                ? null
                : Builder(
                  builder:
                      (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                ),
      ),
      drawer: isWeb ? null : const AppDrawer(),
      body:
          isWeb
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppDrawer(),
                  Expanded(child: _buildContent(context, isWeb)),
                ],
              )
              : _buildContent(context, isWeb),
    );
  }

  Widget _buildContent(BuildContext context, bool isWeb) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - (isWeb ? 48 : 32);
        return SingleChildScrollView(
          child: Padding(
            padding:
                isWeb
                    ? const EdgeInsets.fromLTRB(24, 24, 24, 16)
                    : const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subjects',
                  style: TextStyle(
                    fontSize: isWeb ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0C4D83),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Subjects',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    prefixIcon: const Icon(Icons.search),
                  ),
                  style: TextStyle(fontSize: isWeb ? 16 : 14),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: isWeb ? null : availableHeight - 84,
                  child:
                      _filteredSubjectList.isEmpty
                          ? const Center(child: Text('No subjects found.'))
                          : isWeb
                          ? GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 400,
                                  childAspectRatio: 1.8,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: _filteredSubjectList.length,
                            itemBuilder: (context, index) {
                              return _buildSubjectCard(
                                context,
                                _filteredSubjectList[index],
                                isWeb,
                              );
                            },
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredSubjectList.length,
                            itemBuilder: (context, index) {
                              return _buildSubjectCard(
                                context,
                                _filteredSubjectList[index],
                                isWeb,
                              );
                            },
                          ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showAddForm = !_showAddForm;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding:
                          isWeb
                              ? const EdgeInsets.symmetric(
                                vertical: 14.0,
                                horizontal: 30.0,
                              )
                              : const EdgeInsets.symmetric(
                                vertical: 12.0,
                                horizontal: 24.0,
                              ),
                      elevation: 6,
                    ),
                    child: Text(
                      _showAddForm ? 'Hide Form' : 'Add New Subject',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isWeb ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_showAddForm)
                  Card(
                    elevation: isWeb ? 8 : 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Padding(
                      padding:
                          isWeb
                              ? const EdgeInsets.all(20.0)
                              : const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Subject Details',
                              style: TextStyle(
                                fontSize: isWeb ? 20 : 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0C4D83),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _subjectNameController,
                              decoration: InputDecoration(
                                labelText: 'Subject Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              style: TextStyle(fontSize: isWeb ? 16 : 14),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a subject name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _subjectCodeController,
                              decoration: InputDecoration(
                                labelText: 'Subject Code',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              style: TextStyle(fontSize: isWeb ? 16 : 14),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a subject code';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _addSubject,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  padding:
                                      isWeb
                                          ? const EdgeInsets.symmetric(
                                            vertical: 14.0,
                                            horizontal: 30.0,
                                          )
                                          : const EdgeInsets.symmetric(
                                            vertical: 12.0,
                                            horizontal: 24.0,
                                          ),
                                  elevation: 6,
                                ),
                                child:
                                    _isLoading
                                        ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                        : Text(
                                          'Add Subject',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isWeb ? 16 : 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectCard(
    BuildContext context,
    Map<String, dynamic> subject,
    bool isWeb,
  ) {
    return MouseRegion(
      cursor: isWeb ? SystemMouseCursors.click : MouseCursor.defer,
      child: Card(
        elevation: isWeb ? 6 : 4,
        margin:
            isWeb
                ? const EdgeInsets.symmetric(vertical: 6)
                : const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Container(
          decoration:
              isWeb
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  )
                  : null,
          child: ListTile(
            contentPadding:
                isWeb
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            title: Text(
              subject['subject_name'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isWeb ? 18 : 16,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Code: ${subject['subject_code'] ?? 'N/A'}',
                  style: TextStyle(fontSize: isWeb ? 14 : 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    _subjectCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
