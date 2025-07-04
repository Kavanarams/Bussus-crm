import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../providers/data_provider.dart';

class AllFilesPage extends StatefulWidget {
  final List<Map<String, dynamic>> files;
  final Function(String)? onFileDeleted;
  final VoidCallback? onFileUpdated;
  
  const AllFilesPage({
    Key? key, 
    required this.files,
    this.onFileDeleted,
    this.onFileUpdated,
  }) : super(key: key);

  @override
  State<AllFilesPage> createState() => _AllFilesPageState();
}

class _AllFilesPageState extends State<AllFilesPage> {
  late List<Map<String, dynamic>> _files;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.files);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('All Files'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer<DataProvider>(
        builder: (context, dataProvider, child) {
          if (dataProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (_files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No files found',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          // Separate images from other files like in details page
          final images = _files.where((attachment) {
            final String fileType = attachment['type'] ?? '';
            final String fileName = attachment['name'] ?? attachment['file_name'] ?? '';
            return fileType == 'image' || 
                ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(fileName.split('.').last.toLowerCase());
          }).toList();
          
          final otherFiles = _files.where((attachment) {
            final String fileType = attachment['type'] ?? '';
            final String fileName = attachment['name'] ?? attachment['file_name'] ?? '';
            return !(fileType == 'image' || 
                ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(fileName.split('.').last.toLowerCase()));
          }).toList();

          return SingleChildScrollView(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            child: Column(
              children: [
                // Images Section
                if (images.isNotEmpty) ...[
                  _buildSectionHeader('Images', images.length),
                  SizedBox(height: AppDimensions.spacingM),
                  ...images.map((image) => _buildImagePreview(image)).toList(),
                  SizedBox(height: AppDimensions.spacingL),
                ],
                
                // Other Files Section
                if (otherFiles.isNotEmpty) ...[
                  _buildSectionHeader('Other Files', otherFiles.length),
                  SizedBox(height: AppDimensions.spacingM),
                  Card(
                    child: ListView.separated(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: otherFiles.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade800, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final file = otherFiles[index];
                        return _buildFileItem(file);
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          '$title ($count)',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildImagePreview(Map<String, dynamic> image) {
    final fileName = image['file_name'] ?? image['name'] ?? 'Unknown';
    final uploadDate = _formatDateTime(image['created_at'] ?? image['upload_date'] ?? '');
    final imageUrl = image['file_url'] ?? image['url'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image display
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: 300,
              minHeight: 150,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusM)),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 150,
                              color: Colors.grey[300],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
                                  SizedBox(height: 8),
                                  Text('Failed to load image', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: double.infinity,
                              height: 150,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          width: double.infinity,
                          height: 150,
                          color: Colors.grey[300],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, size: 48, color: Colors.grey[600]),
                              SizedBox(height: 8),
                              Text('No image URL', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                ),
                // Overlay with edit/delete options - only visible on hover or tap
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showEditDialog(image);
                            break;
                          case 'delete':
                            _showDeleteConfirmation(image);
                            break;
                          case 'view':
                            _viewFile(image);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility),
                              SizedBox(width: 8),
                              Text('View'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // File info
          Padding(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File name as hyperlink
                InkWell(
                  onTap: () => _viewFile(image),
                  child: Text(
                    fileName,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXs),
                Text(
                  'Uploaded: $uploadDate',
                  style: AppTextStyles.labelText,
                ),
                if (image['owner'] != null) ...[
                  SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    'By: ${image['owner']}',
                    style: AppTextStyles.labelText,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(Map<String, dynamic> file) {
    final fileName = file['file_name'] ?? file['name'] ?? 'Unknown';
    final uploadDate = _formatDateTime(file['created_at'] ?? file['upload_date'] ?? '');
    final fileIcon = _getFileIcon(fileName);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        child: Icon(
          fileIcon,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: InkWell(
        onTap: () => _viewFile(file),
        child: Text(
          fileName,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uploaded: $uploadDate',
            style: AppTextStyles.labelText,
          ),
          if (file['owner'] != null)
            Text(
              'By: ${file['owner']}',
              style: AppTextStyles.labelText,
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _showEditDialog(file);
              break;
            case 'delete':
              _showDeleteConfirmation(file);
              break;
            case 'view':
              _viewFile(file);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.visibility),
                SizedBox(width: 8),
                Text('View'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text('Rename'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _viewFile(Map<String, dynamic> attachment) {
    final url = attachment['file_url'] ?? attachment['url'];
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File URL not available')),
      );
      return;
    }
    
    // Add your file viewing logic here
    // For example, you could use url_launcher to open the file
    // or navigate to a file viewer page
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('View File'),
        content: Text('File URL: $url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> attachment) {
    final TextEditingController controller = TextEditingController(
      text: attachment['file_name'] ?? attachment['name'] ?? '',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'File Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _updateFileName(attachment, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> attachment) {
    final fileName = attachment['file_name'] ?? attachment['name'] ?? 'this file';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(attachment);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFileName(Map<String, dynamic> attachment, String newName) async {
    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updating file name...'),
          duration: Duration(seconds: 3),
        ),
      );

      // Use the correct method signature from your DataProvider
      final fileId = attachment['id'] ?? attachment['file_id'];
      final updateData = {
        'id': fileId,
        'name': newName,
      };
      
      final result = await dataProvider.updateFileName(updateData);
      
      if (result['success'] == true) {
        // Update the local file list
        setState(() {
          final index = _files.indexWhere((file) => 
            (file['id'] ?? file['file_id']) == fileId);
          if (index != -1) {
            _files[index]['file_name'] = newName;
            _files[index]['name'] = newName;
          }
        });
        
        // Call the callback to notify parent
        widget.onFileUpdated?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File name updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update file name: ${dataProvider.error ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating file name: $e')),
      );
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> attachment) async {
    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting file...'),
          duration: Duration(seconds: 5),
        ),
      );

      // Use the correct method signature from your DataProvider
      final fileId = attachment['id'] ?? attachment['file_id'];
      final fileName = attachment['file_name'] ?? attachment['name'] ?? '';
      
      final success = await dataProvider.deleteFile(fileId, fileName);
      
      if (success) {
        // Remove from local list
        setState(() {
          _files.removeWhere((file) => 
            (file['id'] ?? file['file_id']) == fileId);
        });
        
        // Call the callback to notify parent
        widget.onFileDeleted?.call(fileId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted successfully')),
        );
        
        // If no files left, pop back to parent
        if (_files.isEmpty) {
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete file: ${dataProvider.lastError ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting file: $e')),
      );
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      DateTime dateTime;
      final DateTime now = DateTime.now();
      final DateTime yesterday = now.subtract(const Duration(days: 1));

      // Fixed RegExp patterns - properly closed raw strings
      if (RegExp(r'^\d+$').hasMatch(dateTimeStr)) {
        // Unix timestamp in seconds
        dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(dateTimeStr) * 1000);
      } else if (RegExp(r'^\d{13}$').hasMatch(dateTimeStr)) {
        // Unix timestamp in milliseconds
        dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(dateTimeStr));
      } else {
        // Try parsing as ISO string
        dateTime = DateTime.parse(dateTimeStr);
      }

      // Format based on date
      if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
        // Today
        return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (dateTime.year == yesterday.year && dateTime.month == yesterday.month && dateTime.day == yesterday.day) {
        // Yesterday
        return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (dateTime.year == now.year) {
        // This year
        return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        // Previous years
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      print('Error parsing date: $dateTimeStr, Error: $e');
      return dateTimeStr.isNotEmpty ? dateTimeStr : 'Unknown';
    }
  }
}