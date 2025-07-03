class App {
  final String id;
  final String name;
  final String label;
  final String? description;
  final String? color;
  final String? image;
  final List<AppTab> tabs;
  final String developer;
  final String setupExperience;
  final String navigationStyle;
  final String formFactor;
  final bool disableEndUserPersonalisation;
  final bool disableTemporaryTabs;
  final bool useAppImageColorForOrgTheme;
  final bool useOmniChannelSidebar;
  final String createdBy;
  final String lastModifiedBy;
  final DateTime createdDate;
  final DateTime lastModifiedDate;
  final String organisation;
  final String? logo;
  final String? utilityBar;
  final String? defaultLandingTab;

  App({
    required this.id,
    required this.name,
    required this.label,
    this.description,
    this.color,
    this.image,
    required this.tabs,
    required this.developer,
    required this.setupExperience,
    required this.navigationStyle,
    required this.formFactor,
    required this.disableEndUserPersonalisation,
    required this.disableTemporaryTabs,
    required this.useAppImageColorForOrgTheme,
    required this.useOmniChannelSidebar,
    required this.createdBy,
    required this.lastModifiedBy,
    required this.createdDate,
    required this.lastModifiedDate,
    required this.organisation,
    this.logo,
    this.utilityBar,
    this.defaultLandingTab,
  });

  factory App.fromJson(Map<String, dynamic> json) {
    return App(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      description: json['description'],
      color: json['color'],
      image: json['image'],
      tabs: (json['tabs'] as List<dynamic>?)
          ?.map((tab) => AppTab.fromJson(tab))
          .toList() ?? [],
      developer: json['developer'] ?? '',
      setupExperience: json['setup_experiance'] ?? '',
      navigationStyle: json['navigation_style'] ?? '',
      formFactor: json['form_factor'] ?? '',
      disableEndUserPersonalisation: json['disable_end_user_personalisation'] ?? false,
      disableTemporaryTabs: json['disable_temporary_tabs'] ?? false,
      useAppImageColorForOrgTheme: json['use_app_image_color_for_org_theme'] ?? false,
      useOmniChannelSidebar: json['use_omni_channel_sidebar'] ?? false,
      createdBy: json['created_by'] ?? '',
      lastModifiedBy: json['last_modified_by'] ?? '',
      createdDate: DateTime.tryParse(json['created_date'] ?? '') ?? DateTime.now(),
      lastModifiedDate: DateTime.tryParse(json['last_modified_date'] ?? '') ?? DateTime.now(),
      organisation: json['organisation'] ?? '',
      logo: json['logo'],
      utilityBar: json['utility_bar'],
      defaultLandingTab: json['default_landing_tab'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'description': description,
      'color': color,
      'image': image,
      'tabs': tabs.map((tab) => tab.toJson()).toList(),
      'developer': developer,
      'setup_experiance': setupExperience,
      'navigation_style': navigationStyle,
      'form_factor': formFactor,
      'disable_end_user_personalisation': disableEndUserPersonalisation,
      'disable_temporary_tabs': disableTemporaryTabs,
      'use_app_image_color_for_org_theme': useAppImageColorForOrgTheme,
      'use_omni_channel_sidebar': useOmniChannelSidebar,
      'created_by': createdBy,
      'last_modified_by': lastModifiedBy,
      'created_date': createdDate.toIso8601String(),
      'last_modified_date': lastModifiedDate.toIso8601String(),
      'organisation': organisation,
      'logo': logo,
      'utility_bar': utilityBar,
      'default_landing_tab': defaultLandingTab,
    };
  }
}

class AppTab {
  final String name;
  final String type;

  AppTab({
    required this.name,
    required this.type,
  });

  factory AppTab.fromJson(Map<String, dynamic> json) {
    return AppTab(
      name: json['name'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
    };
  }
}