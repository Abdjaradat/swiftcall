part of 'home_bloc.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}
class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<ChatModel> chats;
  final List<UserModel> contacts;
  final String myUid;
  final String searchQuery;

  HomeLoaded({
    required this.chats,
    this.contacts = const [],
    this.myUid = '',
    this.searchQuery = '',
  });

  List<ChatModel> get filteredChats {
    if (searchQuery.isEmpty) return chats;
    final q = searchQuery.toLowerCase();
    return chats.where((c) {
      final name = c.otherUser?.name.toLowerCase() ?? '';
      return name.contains(q);
    }).toList();
  }

  List<UserModel> get filteredContacts {
    if (searchQuery.isEmpty) return contacts;
    final q = searchQuery.toLowerCase();
    return contacts.where((u) => u.name.toLowerCase().contains(q)).toList();
  }

  HomeLoaded copyWith({
    List<ChatModel>? chats,
    List<UserModel>? contacts,
    String? myUid,
    String? searchQuery,
  }) {
    return HomeLoaded(
      chats: chats ?? this.chats,
      contacts: contacts ?? this.contacts,
      myUid: myUid ?? this.myUid,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}
