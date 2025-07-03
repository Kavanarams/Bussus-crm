import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_button_styles.dart';
import 'edit_screen.dart';
import 'newtask.dart';
// import 'AllActivitiesScreen.dart';
import 'package:file_picker/file_picker.dart'; 
import 'dart:io' show File;
import 'task_detail_screen.dart';
import '../theme/app_snackbar.dart';
import 'home_screen.dart';
import 'AllFilesPage.dart';


class DetailsScreen extends StatefulWidget {
  final String type;
  final String itemId;

  const DetailsScreen({
    super.key,
    required this.type,
    required this.itemId,
  });

  @override
  _DetailsScreenState createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _details = {};
  List<ColumnInfo> _allColumns = [];
  List<String> _visibleColumns = [];
  String? _error;
  List<Map<String, dynamic>> _layoutSections = [];
  List<Map<String, dynamic>> _activities = [];
  final bool _isLoadingActivities = false;
  bool _activitiesSectionExpanded = false;
  Map<String, dynamic> _relatedData = {};
  List<Map<String, dynamic>> _attachments = [];
  List<Map<String, dynamic>> _history = [];
  bool _relatedSectionExpanded = false;
  bool _attachmentsSectionExpanded = false;
  bool _historySectionExpanded = false;
  bool _showAllActivities = false;          // Controls whether to show all activities or just 2
 
  DynamicModel? _dynamicModel;
  // Add these variables to your widget's state
  bool _showAllImages = false;
  bool _showAllOtherFiles = false;
  
  // Map to keep track of expanded sections - the key is the section title
  final Map<String, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

 
// Replace your _loadDetails method in DetailsScreen with this enhanced version:

Future<void> _loadDetails() async {
  print('📄 Loading details for ${widget.type} ID: ${widget.itemId}');
  
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    
    // Clear any cached data to force fresh load
    print('📄 Fetching fresh data from server...');
    
    // Fetch details using DataProvider
    final result = await dataProvider.fetchItemDetails(widget.type, widget.itemId);
    
    print('📄 Server response received, processing data...');
    
    // Extract raw details and columns
    _details = result['data'] ?? {};
    _allColumns = _extractColumns(result['all_columns'] ?? []);
    _visibleColumns = List<String>.from(result['visible_columns'] ?? []);
    
    // ✅ CREATE A DYNAMICMODEL INSTANCE TO HANDLE RELATIONSHIP FIELDS PROPERLY
    _dynamicModel = DynamicModel.fromJson(_details, _visibleColumns);
    
    print('📄 Item details loaded: ${_details.keys.length} fields');
    print('📄 Item name: ${_details['name'] ?? 'N/A'}');

    // Handle layout sections as a list
    if (result['layout'] != null && result['layout']['sections'] != null) {
      var sections = result['layout']['sections'];
      if (sections is List) {
        _layoutSections = List<Map<String, dynamic>>.from(sections.map((section) =>
          Map<String, dynamic>.from(section)
        ));
        
        // Initialize all sections as collapsed by default
        for (var section in _layoutSections) {
          String title = section['title'] ?? 'Details';
          _expandedSections[title] = true;
        }
        
        // If there's a default section and no layout sections, initialize that too
        if (_layoutSections.isEmpty) {
          _expandedSections['Details'] = false;
        }
      }
    }

    // Load activities from the tasks field
    if (result['tasks'] != null) {
      _activities = List<Map<String, dynamic>>.from(result['tasks']);
      print('📊 Loaded ${_activities.length} activities from preview response');
    } else {
      _activities = [];
      print('📊 No activities found in response');
    }

    // Extract related data
    if (result['related_data'] != null) {
      _relatedData = Map<String, dynamic>.from(result['related_data']);
      print('📊 Loaded related data: ${_relatedData.keys.length} relationships');
    }

    // Extract attachments
    if (result['attachments'] != null) {
      _attachments = List<Map<String, dynamic>>.from(result['attachments']);
      print('📊 Loaded ${_attachments.length} attachments');
    }

    // Extract history
    if (result['history'] != null) {
      _history = List<Map<String, dynamic>>.from(result['history']);
      print('📊 Loaded ${_history.length} history records');
    }

    // Handle error from DataProvider
    if (dataProvider.error != null) {
      setState(() {
        _error = dataProvider.error;
      });
      print('❌ DataProvider error: ${dataProvider.error}');
    } else {
      print('✅ Details loaded successfully');
    }
  } catch (e) {
    setState(() {
      _error = 'Error occurred: $e';
    });
    print('❌ Error processing details: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
    print('📄 Details loading completed');
  }
}
  List<ColumnInfo> _extractColumns(List<dynamic> columns) {
    return columns.map((column) => ColumnInfo.fromJson(column)).toList();
  }

  String _getFieldLabel(String fieldName) {
    for (var column in _allColumns) {
      if (column.name == fieldName) {
        return column.label;
      }
    }
    return fieldName;
  }

  bool _isFieldRequired(String fieldName) {
    for (var column in _allColumns) {
      if (column.name == fieldName) {
        return column.required;
      }
    }
    return false;
  }
  

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(AppDimensions.appBarHeight),
      child: AppBar(
        title: Text("Details"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {}
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {}
          ),
        ],
      ),
    ),
    backgroundColor: AppColors.background,
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!, style: AppTextStyles.bodyMedium))
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderInfo(),
                // Use consistent container for all sections
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL, 
                    vertical: AppDimensions.spacingS
                  ),
                  child: Column(
                    children: [
                      // Layout sections with consistent styling
                      ..._layoutSections.isNotEmpty
                          ? _layoutSections.map((section) {
                              return _buildExpandableSection(section);
                            }).toList()
                          : [_buildExpandableDefaultSection()],
                      // Activities section with consistent styling
                      _buildActivitiesSection(),
                      _buildRelatedSection(),
                      _buildAttachmentsSection(),
                      _buildHistorySection(),
                    ],
                  ),
                ),
              ],
            ),
          ),
    bottomNavigationBar: _buildBottomNavBar(),
  );
}

  Widget _buildRelatedSection() {
  return Card(
    margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
    child: Column(
      children: [
        // Header with expand/collapse functionality
        InkWell(
          onTap: () {
            setState(() {
              _relatedSectionExpanded = !_relatedSectionExpanded;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Related Items',
                      style: AppTextStyles.cardTitle,
                    ),
                    SizedBox(width: AppDimensions.spacingS),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingS, 
                        vertical: AppDimensions.spacingXs
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusBadgeBg,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      ),
                      child: Text(
                        '${_relatedData.keys.length}',
                        style: TextStyle(
                          color: AppColors.statusBadgeText,
                          fontWeight: FontWeight.bold,
                          fontSize: AppDimensions.textS,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _relatedSectionExpanded 
                      ? Icons.keyboard_arrow_up 
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                  size: AppDimensions.iconL,
                ),
              ],
            ),
          ),
        ),
        
        // Content - only visible when expanded
        if (_relatedSectionExpanded) ...[
          Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
          if (_relatedData.isEmpty) 
            Padding(
              padding: EdgeInsets.all(AppDimensions.spacingM),
              child: Text(
                'No related items found',
                style: AppTextStyles.secondaryText,
              ),
            )
          else
            Column(
              children: _relatedData.entries.map((entry) {
                final String relationType = entry.key;
                final List<dynamic> items = entry.value is List ? entry.value : [];
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(AppDimensions.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatRelationType(relationType),
                            style: AppTextStyles.subheading,
                          ),
                          SizedBox(height: AppDimensions.spacingM),
                          if (items.isEmpty)
                            Text(
                              'No ${_formatRelationType(relationType).toLowerCase()} found',
                              style: AppTextStyles.secondaryText,
                            )
                          else
                            Column(
                              children: items.map((item) => _buildRelatedItem(item, relationType)).toList(),
                            ),
                        ],
                      ),
                    ),
                    if (entry.key != _relatedData.keys.last)
                     Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
                  ],
                );
              }).toList(),
            ),
        ],
      ],
    ),
  );
}


String _formatRelationType(String type) {
  // Convert snake_case to Title Case
  return type
      .split('_')
      .map((word) => word.isNotEmpty 
          ? '${word[0].toUpperCase()}${word.substring(1)}' 
          : '')
      .join(' ');
}

Widget _buildRelatedItem(Map<String, dynamic> item, String relationType) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      item['name'] ?? 'Unnamed Item',
      style: AppTextStyles.bodyLarge,
    ),
    trailing: Icon(Icons.chevron_right, color: AppColors.primary),
    onTap: () {
      // Navigate to the details screen for this item
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsScreen(
            type: relationType.contains('_') ? relationType.split('_').last : relationType,
            itemId: item['id'],
          ),
        ),
      );
    },
  );
}
Widget _buildAttachmentsSection() {
  // Separate images from other files
  final images = _attachments.where((attachment) {
    final String fileType = attachment['type'] ?? '';
    final String fileName = attachment['name'] ?? '';
    return fileType == 'image' || 
        ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(fileName.split('.').last.toLowerCase());
  }).toList();
  
  final otherFiles = _attachments.where((attachment) {
    final String fileType = attachment['type'] ?? '';
    final String fileName = attachment['name'] ?? '';
    return !(fileType == 'image' || 
        ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(fileName.split('.').last.toLowerCase()));
  }).toList();

  return Card(
    margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
    child: Column(
      children: [
        // Header with expand/collapse functionality
        InkWell(
          onTap: () {
            setState(() {
              _attachmentsSectionExpanded = !_attachmentsSectionExpanded;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Files',
                      style: AppTextStyles.cardTitle,
                    ),
                    SizedBox(width: AppDimensions.spacingS),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingS, 
                        vertical: AppDimensions.spacingXs
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusBadgeBg,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      ),
                      child: Text(
                        '${_attachments.length}',
                        style: TextStyle(
                          color: AppColors.statusBadgeText,
                          fontWeight: FontWeight.bold,
                          fontSize: AppDimensions.textS,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _attachmentsSectionExpanded 
                      ? Icons.keyboard_arrow_up 
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                  size: AppDimensions.iconL,
                ),
              ],
            ),
          ),
        ),
        
        // Content - only visible when expanded
        if (_attachmentsSectionExpanded) ...[
          Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
          _attachments.isEmpty
            ? Padding(
                padding: EdgeInsets.all(AppDimensions.spacingM),
                child: Text(
                  'No files attached',
                  style: AppTextStyles.secondaryText,
                ),
              )
            : Column(
                children: [
                  // Images Section
                  if (images.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.all(AppDimensions.spacingM),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Images (${images.length})',
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (images.length > 2)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAllImages = !_showAllImages;
                                });
                              },
                              child: Text(
                                _showAllImages ? 'Show Less' : 'View All',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Show images based on view state
                    ...(_showAllImages ? images : images.take(2)).map((image) => _buildImagePreview(image)).toList(),
                    if (!_showAllImages && images.length > 2)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingM, vertical: AppDimensions.spacingS),
                        child: Text(
                          '+${images.length - 2} more images',
                          style: AppTextStyles.labelText,
                        ),
                      ),
                  ],
                  
                  // Other Files Section
                  if (otherFiles.isNotEmpty) ...[
                    if (images.isNotEmpty) Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
                    Padding(
                      padding: EdgeInsets.all(AppDimensions.spacingM),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Other Files (${otherFiles.length})',
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (otherFiles.length > 2)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAllOtherFiles = !_showAllOtherFiles;
                                });
                              },
                              child: Text(
                                _showAllOtherFiles ? 'Show Less' : 'View All',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Show other files based on view state
                    ListView.separated(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _showAllOtherFiles ? otherFiles.length : (otherFiles.length > 2 ? 2 : otherFiles.length),
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final file = otherFiles[index];
                        return _buildFileItem(file);
                      },
                    ),
                    if (!_showAllOtherFiles && otherFiles.length > 2)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingM, vertical: AppDimensions.spacingS),
                        child: Text(
                          '+${otherFiles.length - 2} more files',
                          style: AppTextStyles.labelText,
                        ),
                      ),
                  ],
                ],
              ),
          
          // Add a button to upload new attachments
          Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
          InkWell(
            onTap: () {
              _selectAndUploadFile();
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingL),
              child: Center(
                child: Text(
                  'Upload New File',
                  style: AppTextStyles.actionText,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildImagePreview(Map<String, dynamic> attachment) {
  final String fileName = attachment['name'] ?? 'Unnamed File';
  final String uploadDate = _formatDateTime(attachment['created_at'] ?? attachment['upload_date'] ?? attachment['created_date'] ?? '');
  
  String? rawImageUrl = attachment['url'] ?? attachment['file_path'] ?? attachment['path'];
  String imageUrl = _buildImageUrl(rawImageUrl);
  
  return ListTile(
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      child: Container(
        width: 40,
        height: 40,
        color: Colors.grey.shade200,
        child: rawImageUrl != null
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.image, color: AppColors.primary);
              },
            )
          : Icon(Icons.image, color: AppColors.primary),
      ),
    ),
    title: InkWell(
      onTap: () {
        _viewImageInDialog(attachment);
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              fileName, 
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            ],
          ),
        ],
      ),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppDimensions.spacingXs),
        Text(uploadDate, style: AppTextStyles.labelText),
        if (attachment['owner'] != null)
          Text('By: ${attachment['owner']}', style: AppTextStyles.labelText),
      ],
    ),
  );
}

String _buildImageUrl(String? rawImageUrl) {
  if (rawImageUrl == null || rawImageUrl.isEmpty) {
    return '';
  }
  
  String imageUrl = rawImageUrl;
  if (rawImageUrl.startsWith('/')) {
    imageUrl = 'https://qa.api.bussus.com/media$rawImageUrl';
  } else if (!rawImageUrl.startsWith('http')) {
    imageUrl = 'https://qa.api.bussus.com/media/$rawImageUrl';
  }
  
  return imageUrl;
}

Widget _buildFileItem(Map<String, dynamic> attachment) {
  final String fileName = attachment['name'] ?? 'Unnamed File';
  final String uploadDate = _formatDateTime(attachment['created_at'] ?? attachment['upload_date'] ?? attachment['created_date'] ?? '');
  final String fileType = attachment['type'] ?? '';
  
  IconData fileIcon = _getFileIcon(fileName, fileType);
  
  return ListTile(
    leading: Icon(fileIcon, color: AppColors.primary, size: AppDimensions.iconL),
    title: Row(
      children: [
        Expanded(
          child: Text(fileName, style: AppTextStyles.bodyLarge),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.primary, size: 18),
              onPressed: () {
                _editFileName(attachment);
              },
              tooltip: 'Edit Name',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.primary, size: 18),
              onPressed: () {
                _confirmDeleteFile(attachment);
              },
              tooltip: 'Delete',
            ),
          ],
        ),
      ],
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppDimensions.spacingXs),
        Text(uploadDate, style: AppTextStyles.labelText),
        if (attachment['owner'] != null)
          Text('By: ${attachment['owner']}', style: AppTextStyles.labelText),
      ],
    ),
  );
}

void _viewImageInDialog(Map<String, dynamic> attachment) {
  String? rawImageUrl = attachment['url'] ?? attachment['file_path'] ?? attachment['path'];
  final String fileName = attachment['name'] ?? 'Image';
  
  if (rawImageUrl == null || rawImageUrl.isEmpty) {
    AppSnackBar.showError(context, 'Image URL not available');
    return;
  }
  
  String imageUrl = _buildImageUrl(rawImageUrl);
  
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () {
                    Navigator.pop(context);
                    _editFileName(attachment);
                  },
                  tooltip: 'Edit Name',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.primary),
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDeleteFile(attachment);
                  },
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxHeight: 400,
                ),
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                            SizedBox(height: 10),
                            Text(
                              'Failed to load image',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    },
  );
}

String _formatDateTime(String dateTimeStr) {
  try {
    if (dateTimeStr.isEmpty) return '';
    
    DateTime dateTime;
    
    // Handle different timestamp formats
    if (dateTimeStr.contains('T')) {
      // ISO format
      dateTime = DateTime.parse(dateTimeStr);
    } else if (dateTimeStr.contains(' ')) {
      // Format like "2024-01-15 10:30:45"
      dateTime = DateTime.parse(dateTimeStr);
    } else if (RegExp(r'^\d+$').hasMatch(dateTimeStr)) {
      // Unix timestamp (seconds)
      dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(dateTimeStr) * 1000);
    } else if (RegExp(r'^\d{13}$').hasMatch(dateTimeStr)) {
      // Unix timestamp (milliseconds)
      dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(dateTimeStr));
    } else {
      // Try parsing as is
      dateTime = DateTime.parse(dateTimeStr);
    }
    
    final DateTime now = DateTime.now();
    final DateTime yesterday = now.subtract(Duration(days: 1));
    
    // Format for today
    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      return 'Today at ${_formatTime(dateTime)}';
    }
    // Format for yesterday
    else if (dateTime.year == yesterday.year && dateTime.month == yesterday.month && dateTime.day == yesterday.day) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    }
    // Format for this year
    else if (dateTime.year == now.year) {
      return '${_getMonthName(dateTime.month)} ${dateTime.day} at ${_formatTime(dateTime)}';
    }
    // Format for other years
    else {
      return '${_getMonthName(dateTime.month)} ${dateTime.day}, ${dateTime.year} at ${_formatTime(dateTime)}';
    }
  } catch (e) {
    print('Error parsing date: $dateTimeStr, Error: $e');
    return dateTimeStr;
  }
}

String _formatTime(DateTime dateTime) {
  final int hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
  final String minute = dateTime.minute.toString().padLeft(2, '0');
  final String period = dateTime.hour >= 12 ? 'PM' : 'AM';
  
  return '$hour:$minute $period';
}

String _getMonthName(int month) {
  const List<String> months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  
  return months[month - 1];
}

IconData _getFileIcon(String fileName, String fileType) {
  // First check the file type
  if (fileType == 'image') {
    return Icons.image;
  } else if (fileType == 'document') {
    return Icons.description;
  } else if (fileType == 'spreadsheet') {
    return Icons.table_chart;
  } else if (fileType == 'presentation') {
    return Icons.slideshow;
  } else if (fileType == 'pdf') {
    return Icons.picture_as_pdf;
  } else if (fileType == 'audio') {
    return Icons.audio_file;
  } else if (fileType == 'video') {
    return Icons.video_file;
  }
  
  // If file type is not specific, check extension
  final extension = fileName.split('.').last.toLowerCase();
  
  switch (extension) {
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'doc':
    case 'docx':
      return Icons.description;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'bmp':
      return Icons.image;
    case 'mp3':
    case 'wav':
    case 'ogg':
      return Icons.audio_file;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return Icons.video_file;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip;
    case 'txt':
      return Icons.text_snippet;
    default:
      return Icons.insert_drive_file;
  }
}

void _editFileName(Map<String, dynamic> attachment) {
  final String fileId = attachment['id'] ?? '';
  final String currentName = attachment['name'] ?? '';
  
  if (fileId.isEmpty) {
    AppSnackBar.showError(context, 'File ID not available');
    return;
  }
  
  // Split filename and extension
  final List<String> nameParts = currentName.split('.');
  final String extension = nameParts.length > 1 ? nameParts.last : '';
  String nameWithoutExtension = nameParts.length > 1 
      ? nameParts.sublist(0, nameParts.length - 1).join('.') 
      : currentName;
  
  // Controller for the text field
  final TextEditingController nameController = TextEditingController(text: nameWithoutExtension);
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      title: Text('Edit File Name', style: AppTextStyles.subheading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'File Name',
              hintText: 'Enter new file name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            style: AppTextStyles.bodyMedium,
            autofocus: true,
          ),
          SizedBox(height: AppDimensions.spacingS),
          Text(
            'File extension will remain as .$extension',
            style: AppTextStyles.secondaryText,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: AppButtonStyles.dialogCancelButton,
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Get new name with extension
            final String newName = nameController.text.trim() + (extension.isNotEmpty ? '.$extension' : '');
            // Close dialog and update file name
            Navigator.pop(context);
            _updateFileName(fileId, newName);
          },
          style: AppButtonStyles.dialogConfirmButton,
          child: Text('Save'),
        ),
      ],
    ),
  );
}

// Method to update file name via API
Future<void> _updateFileName(String fileId, String newName) async {
  try {
    // Show loading indicator
    AppSnackBar.showInfo(context, 'Updating file name...', customDuration: Duration(seconds: 10));
    
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    
    // Create payload for the PATCH request
    final Map<String, dynamic> payload = {
      'id': fileId,
      'name': newName,
    };
    
    // Call the method to update file name (this will need to be added to DataProvider)
    final response = await dataProvider.updateFileName(payload);
    
    
    if (response['success']) {
      // Show success message
      AppSnackBar.showSuccess(context, 'File name updated successfully', customDuration: Duration(seconds: 2));
      
      // Refresh the screen to get updated data
      _loadDetails();
    } else {
      // Show error message
      AppSnackBar.showError(context, dataProvider.error ?? 'Failed to update file name', customDuration: Duration(seconds: 3));
    }
  } catch (e) {
    print('❌ Error updating file name: $e');
    AppSnackBar.showError(context, 'Error updating file name: $e', customDuration: Duration(seconds: 3));
  }
}

// First, add the missing _inspectAttachment method
void _inspectAttachment(Map<String, dynamic> attachment) {
  // Print out attachment details for debugging
  print('🔍 Inspecting attachment:');
  attachment.forEach((key, value) {
    print('- $key: $value');
  });
  
  // Check for required fields
  final String fileId = attachment['id'] ?? '';
  final String filePath = attachment['file_path'] ?? '';
  
  print('Essential fields:');
  print('- File ID: ${fileId.isNotEmpty ? '✓ Present' : '❌ Missing'} ($fileId)');
  print('- File Path: ${filePath.isNotEmpty ? '✓ Present' : '❌ Missing'} ($filePath)');
}
// Add missing method for deleting files
// Updated _testAllDeleteApproaches function with the correct implementation
Future<void> _testAllDeleteApproaches(Map<String, dynamic> attachment) async {
  try {
    // First, inspect the attachment to see what we're working with
    _inspectAttachment(attachment);
    
    // Show loading indicator
    AppSnackBar.showInfo(context, 'Deleting file...', customDuration: Duration(seconds: 5));
    
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    
    // Extract ID and path from attachment
    final String fileId = attachment['id'] ?? '';
    final String filePath = attachment['file_path'] ?? '';
    final String fileName = filePath.split('/').last;
    
    print('🧪 Attempting to delete file:');
    print('- File ID: $fileId');
    print('- File Path: $filePath');
    print('- File Name: $fileName');
    
    // Use the new method that matches the React implementation
    final success = await dataProvider.deleteFile(fileId, filePath);
    
    // Dismiss any current snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    if (success) {
      // Show success message
      AppSnackBar.showSuccess(context, 'File deleted successfully');
      
      // Remove the file from the list
      setState(() {
        _attachments.removeWhere((file) => file['id'] == fileId);
      });
      
      // Refresh the screen to get updated data
      _loadDetails();
    } else {
      // Show error message
      AppSnackBar.showError(context, 'Failed to delete file: ${dataProvider.lastError}');
    }
  } catch (e) {
    print('❌ Error in test method: $e');
    AppSnackBar.showError(context, 'Error deleting file: $e');
  }
}

// Updated confirm delete function to use the simpler approach
void _confirmDeleteFile(Map<String, dynamic> attachment) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      title: Text('Confirm Delete', style: AppTextStyles.subheading),
      content: Text('Are you sure you want to delete this file?', style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: AppButtonStyles.dialogCancelButton,
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: AppButtonStyles.dialogConfirmButton,
          child: Text('Delete'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    // When confirmed, use the direct approach rather than testing multiple methods
    await _testAllDeleteApproaches(attachment);
  }
}
Future<void> _selectAndUploadFile() async {
  try {
    // Show file picker
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    
    if (result != null) {
      PlatformFile platformFile = result.files.first;
      
      // Show loading indicator
      AppSnackBar.showInfo(context, 'Uploading ${platformFile.name}...', customDuration: Duration(seconds: 30));

      
      // Create a File object from the picked file
      File file = File(platformFile.path!);
      
      // Get the DataProvider to upload the file
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final uploadResult = await dataProvider.uploadFile(
        widget.type,
        widget.itemId,
        file,
      );
      
      // Dismiss the current snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (uploadResult['success']) {
        // Show success message
        AppSnackBar.showSuccess(context, 'File uploaded successfully!', customDuration: Duration(seconds: 2));
        
        // Add the new file to the attachments list in the UI
        setState(() {
          _attachments.add(uploadResult['data']);
        });
        
        // Refresh the entire screen to get updated data from the server
        _loadDetails();
      } else {
        // Show error message
        AppSnackBar.showError(context, dataProvider.error ?? 'Failed to upload file');
      }
    }
  } catch (e) {
    print('❌ Error picking or uploading file: $e');
    AppSnackBar.showError(context, 'Error uploading file: $e');
  }
}
Widget _buildHistorySection() {
  return Card(
    margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
    child: Column(
      children: [
        // Header with expand/collapse functionality
        InkWell(
          onTap: () {
            setState(() {
              _historySectionExpanded = !_historySectionExpanded;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${widget.type.capitalize()} History',
                      style: AppTextStyles.cardTitle,
                    ),
                    SizedBox(width: AppDimensions.spacingS),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingS, 
                        vertical: AppDimensions.spacingXs
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusBadgeBg,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      ),
                      child: Text(
                        '${_history.length}',
                        style: TextStyle(
                          color: AppColors.statusBadgeText,
                          fontWeight: FontWeight.bold,
                          fontSize: AppDimensions.textS,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _historySectionExpanded 
                      ? Icons.keyboard_arrow_up 
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                  size: AppDimensions.iconL,
                ),
              ],
            ),
          ),
        ),
        
        // Content - only visible when expanded
        if (_historySectionExpanded) ...[
          Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
          _history.isEmpty
            ? Padding(
                padding: EdgeInsets.all(AppDimensions.spacingM),
                child: Text(
                  'No history records found',
                  style: AppTextStyles.secondaryText,
                ),
              )
            : ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _history.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
                itemBuilder: (context, index) {
                  final historyItem = _history[index];
                  return _buildHistoryItem(historyItem);
                },
              ),
        ],
      ],
    ),
  );
}


Widget _buildHistoryItem(Map<String, dynamic> historyItem) {
  final String fieldName = _getFieldLabel(historyItem['field_name'] ?? '');
  final String oldValue = historyItem['old_value'] ?? 'N/A';
  final String newValue = historyItem['new_value'] ?? 'N/A';
  final String changeDate = _formatDateTime(historyItem['changed_at'] ?? '');
  
  return ListTile(
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppDimensions.spacingL, 
      vertical: AppDimensions.spacingS
    ),
    title: Text(fieldName, style: AppTextStyles.bodyLarge),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppDimensions.spacingS),
        Row(
          children: [
            Text('Changed from: ', style: AppTextStyles.labelText),
            Text(oldValue, style: AppTextStyles.fieldValue),
          ],
        ),
        SizedBox(height: AppDimensions.spacingXxs),
        Row(
          children: [
            Text('To: ', style: AppTextStyles.labelText),
            Text(newValue, style: AppTextStyles.fieldValue),
          ],
        ),
        SizedBox(height: AppDimensions.spacingXxs),
        Row(
          children: [
            Text('On: ', style: AppTextStyles.labelText),
            Text(changeDate, style: AppTextStyles.fieldValue),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildHeaderInfo() {
    // Get the title (Mr, Mrs, etc.) if available
    String title = _details['title'] ?? '';

    // Get the name of the item
    String name = _details['name'] ?? 'Unknown';

    // Capitalize the first letter of title and name
    if (title.isNotEmpty) {
      title = title.substring(0, 1).toUpperCase() + title.substring(1).toLowerCase();
    }

    // If name contains multiple words, capitalize each word
    List<String> nameParts = name.split(' ');
    String capitalizedName = nameParts.map((part) {
      if (part.isNotEmpty) {
        return part.substring(0, 1).toUpperCase() + part.substring(1).toLowerCase();
      }
      return part;
    }).join(' ');

    // Combine title and name if title exists
    String displayName = title.isNotEmpty ? "$title $capitalizedName" : capitalizedName;

    // First get the capitalized object type
    String objectType = widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1).toLowerCase();

    return Container(
      color: AppColors.cardBackground,
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL, 
        vertical: AppDimensions.spacingL
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with action icons - positioned at the top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Edit Icon (Pencil)
              _buildActionButton(
                Icons.edit,
                'Edit',
                () async {
                  print('📝 Navigating to edit screen...');
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditItemScreen(
                        type: widget.type,
                        itemId: widget.itemId,
                      ),
                    ),
                  );
                  
                  print('📝 Edit screen returned with result: $result');
                  
                  if (result == true) {
                    print('📝 Edit was successful, refreshing details...');
                    // Reload the details to show updated data
                    await _loadDetails();
                    
                    // Show success message
                    AppSnackBar.showSuccess(context, 'Item updated successfully');
                  }
                },
              ),

              // Delete Icon
              _buildActionButton(
                Icons.delete,
                'Delete',
                () async {
                  await _handleDelete();
                },
              ),

              // Task Icon (New/Add Activity)
              _buildActionButton(
                Icons.task_alt,
                'Task',
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskFormScreen(
                        relatedObjectId: widget.itemId,
                        relatedObjectType: widget.type,
                        relatedObjectName: _details['name'],
                      ),
                    ),
                  );
                  
                  // If task was successfully created, reload details
                  if (result == true) {
                    _loadDetails();
                  }
                },
              ),

              // More Icon
              _buildActionButton(
                Icons.more_horiz,
                'More',
                () {
                  // Add more functionality here
                },
              ),
            ],
          ),

          // Add some spacing between icons and text
          SizedBox(height: AppDimensions.spacingL),

          // Object type (Lead, Account, etc.)
          Text(
            objectType,
            style: AppTextStyles.secondaryText,
          ),

          // Name with title
          Text(
            displayName,
            style: AppTextStyles.heading,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: AppDimensions.circleRadius,
          backgroundColor: AppColors.actionButtonBackground,
          child: IconButton(
            icon: Icon(icon, color: AppColors.primary, size: AppDimensions.iconS),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: AppDimensions.spacingXs),
        Text(label, style: AppTextStyles.smallActionText),
      ],
    );
  }
  
  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        title: Text('Confirm Delete', style: AppTextStyles.subheading),
        content: Text('Are you sure you want to delete this item?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppButtonStyles.dialogCancelButton,
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.dialogConfirmButton,
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final success = await dataProvider.deleteItem(widget.type, widget.itemId);
      
      if (success) {
        AppSnackBar.showSuccess(context, 'Item deleted successfully');
        Navigator.pop(context, true);
      } else {
        AppSnackBar.showError(context, dataProvider.error ?? 'Failed to delete item');
      }
    }
  }

  Widget _buildExpandableSection(Map<String, dynamic> section) {
    final title = section['title'] ?? 'Details';
    final fields = List<String>.from(section['fields'] ?? []);
    final isExpanded = _expandedSections[title] ?? false;

    return Card(
      margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
      child: Column(
        children: [
          // Clickable header with arrow
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections[title] = !isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle,
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: AppDimensions.iconL,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
            Padding(
              padding: EdgeInsets.all(AppDimensions.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...fields.map<Widget>((fieldName) {
                    if (!_details.containsKey(fieldName)) return const SizedBox();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem(
                            _getFieldLabel(fieldName),
                            // ✅ CHANGED: Use DynamicModel to get display value
                            _formatValue(_dynamicModel?.getDisplayValue(fieldName, defaultValue: '') ?? _details[fieldName]),
                            _isFieldRequired(fieldName)
                        ),
                        Divider(color: Colors.grey.shade800, thickness: 0.5),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandableDefaultSection() {
    final isExpanded = _expandedSections['Details'] ?? false;
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Column(
        children: [
          // Clickable header with arrow
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections['Details'] = !isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Details',
                    style: AppTextStyles.cardTitle,
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: AppDimensions.iconL,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
            Padding(
              padding: EdgeInsets.all(AppDimensions.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._details.entries.map<Widget>((entry) {
                    if (!_visibleColumns.contains(entry.key) || entry.key == 'id') {
                      return const SizedBox();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem(
                            _getFieldLabel(entry.key),
                            // ✅ CHANGED: Use DynamicModel to get display value
                            _formatValue(_dynamicModel?.getDisplayValue(entry.key, defaultValue: '') ?? entry.value),
                            _isFieldRequired(entry.key)
                        ),
                        Divider(color: Colors.grey.shade800, thickness: 0.5),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoItem(String title, String value, bool required) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              "$title${required ? ' *' : ''}",
              style: AppTextStyles.fieldLabel
          ),
          Text(
              value,
              style: AppTextStyles.fieldValue
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';

    if (value is bool) {
      return value ? 'Yes' : 'No';
    } else if (value is Map) {
      return value.isEmpty ? 'N/A' : value.toString();
    } else if (value is List) {
      return value.isEmpty ? 'N/A' : value.join(', ');
    } else {
      return value.toString().isEmpty ? 'N/A' : value.toString();
    }
  }

 Widget _buildActivitiesSection() {
  // Count open activities (not completed)
  int activitiesCount = _activities.length;
  
  // State variable for expanded view - instead of navigating to a new page
  // We'll use _activitiesSectionExpanded to control initial expansion
  // And add a new state variable _showAllActivities to control showing all tasks
  
  return Card(
    margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
    child: Column(
      children: [
        // Header with expand/collapse functionality
        InkWell(
          onTap: () {
            setState(() {
              _activitiesSectionExpanded = !_activitiesSectionExpanded;
              // Reset show all when collapsing the section
              if (!_activitiesSectionExpanded) {
                _showAllActivities = false;
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Open Activities',
                      style: AppTextStyles.cardTitle,
                    ),
                    SizedBox(width: AppDimensions.spacingS),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingS, 
                        vertical: AppDimensions.spacingXs
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusBadgeBg,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      ),
                      child: Text(
                        '$activitiesCount',
                        style: TextStyle(
                          color: AppColors.statusBadgeText,
                          fontWeight: FontWeight.bold,
                          fontSize: AppDimensions.textS,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _activitiesSectionExpanded 
                      ? Icons.keyboard_arrow_up 
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                  size: AppDimensions.iconL,
                ),
              ],
            ),
          ),
        ),
        
        // Activities list - only visible when expanded, limited to 2 items unless showAll is true
        if (_activitiesSectionExpanded) ...[
          Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
          _isLoadingActivities
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.spacingM),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _activities.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(AppDimensions.spacingM),
                      child: Text(
                        'No activities found',
                        style: AppTextStyles.secondaryText,
                      ),
                    )
                  : Column(
                      children: [
                        ListView.separated(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          // Show all items if _showAllActivities is true, otherwise show just 2
                          itemCount: _showAllActivities ? _activities.length : (_activities.length > 2 ? 2 : _activities.length),
                          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
                          itemBuilder: (context, index) {
                            final activity = _activities[index];
                            return _buildActivityItem(activity);
                          },
                        ),
                        
                        // Add "View All" button if there are more than 2 activities and not showing all yet
                        if (_activities.length > 2 && !_showAllActivities) ...[
                          Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
                          InkWell(
                            onTap: () {
                              // Instead of navigating, we'll set state to show all activities
                              setState(() {
                                _showAllActivities = true;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingL),
                              child: Center(
                                child: Text(
                                  'View All Activities',
                                  style: AppTextStyles.actionText,
                                ),
                              ),
                            ),
                          ),  
                        ],
                        
                        // Add "Show Less" button when showing all activities
                        if (_showAllActivities && _activities.length > 2) ...[
                          Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showAllActivities = false;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingL),
                              child: Center(
                                child: Text(
                                  'Show Less',
                                  style: AppTextStyles.actionText,
                                ),
                              ),
                            ),
                          ),  
                        ],
                      ],
                    ),
        ],
      ],
    ),
  );
}

 // Fixed code for the _buildActivityItem method in DetailScreen
Widget _buildActivityItem(Map<String, dynamic> activity) {
  return ListTile(
    dense: true,
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppDimensions.spacingL, 
      vertical: AppDimensions.spacingXs
    ),
    title: Text(
      activity['subject'] ?? 'No Subject',
      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppDimensions.spacingXs),
        Row(
          children: [
            Text(
              'Due Date: ',
              style: AppTextStyles.labelText,
            ),
            Text(
              '${activity['due_date'] ?? 'N/A'}',
              style: AppTextStyles.fieldValue,
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingXxs),
        Row(
          children: [
            Text(
              'Status: ',
              style: AppTextStyles.labelText,
            ),
            Text(
              '${activity['status'] ?? 'N/A'}',
              style: AppTextStyles.fieldValue,
            ),
          ],
        ),
      ],
    ),
    
    trailing: Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL, 
        vertical: AppDimensions.spacingXs
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(activity['status']),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Text(
        activity['status'] ?? '',
        style: AppTextStyles.statusBadge,
      ),
    ),
    // FIXED: Improved navigation and result handling with proper data refresh
    onTap: () async {
      print('📱 Navigating to task detail for ID: ${activity['id']}');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(
            taskId: activity['id'] ?? '',
          ),
        ),
      );
      
      print('📱 Returned from task detail with result: $result');
      
      // Always reload the data when we return, whether the result is true or not
      // This ensures we always have the latest data
      _loadDetails(); // Reload all details including tasks
    },
  );
}
  
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in progress':
        return AppColors.primary;
      case 'on hold':
        return AppColors.warning;
      case 'not started':
        return Colors.grey;
      case 'planned':
        return Colors.purple;
      case 'follow up':
        return Colors.teal;
      case 'cancelled':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }
  
Widget _buildBottomNavBar() {
  return BottomNavigationBar(
    type: BottomNavigationBarType.fixed,
    items: [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
      BottomNavigationBarItem(
        icon: Icon(Icons.business),
        label: widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)
      ),
      BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
    ],
    currentIndex: 1,
    selectedItemColor: AppColors.primary,
    backgroundColor: AppColors.cardBackground,
    elevation: AppDimensions.elevationXl,
    onTap: (index) {
      switch (index) {
        case 0: // Home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainLayout(initialIndex: 0)
            ),
            (route) => false,
          );
          break;
        case 1: // Current page (Details) - do nothing
          break;
        case 2: // Menu
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainLayout(initialIndex: 2)
            ),
            (route) => false,
          );
          break;
      }
    },
  );
}
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}