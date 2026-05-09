part of 'home_bloc.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}
class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<ChatModel> chats;
  final List<UserModel> contacts;
  final List<PhoneContactModel> phoneContacts;
  final bool contactsPermissionDenied;
  final String searchQuery;

  HomeLoaded({
    required this.chats,
    this.contacts = const [],
    this.phoneContacts = const [],
    this.contactsPermissionDenied = false,
    this.searchQuery = '',
  });

  List<ChatModel> get filteredChats {
    if (searchQuery.isEmpty) return chats;
    return chats.where((c) {
      final name = c.otherUser?.name.toLowerCase() ?? '';
      return name.contains(searchQuery.toLowerCase());
    }).toList();
  }

  HomeLoaded copyWith({
    List<ChatModel>? chats,
    List<UserModel>? contacts,
    List<PhoneContactModel>? phoneContacts,
    bool? contactsPermissionDenied,
    String? searchQuery,
  }) {
    return HomeLoaded(
      chats: chats ?? this.chats,
      contacts: contacts ?? this.contacts,
      phoneContacts: phoneContacts ?? this.phoneContacts,
      contactsPermissionDenied:
          contactsPermissionDenied ?? this.contactsPermissionDenied,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}
