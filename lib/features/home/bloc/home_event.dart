part of 'home_bloc.dart';

abstract class HomeEvent {}

class HomeLoadChats extends HomeEvent {}

class HomeSearchChanged extends HomeEvent {
  final String query;
  HomeSearchChanged(this.query);
}

class HomeLoadContacts extends HomeEvent {}

class HomeRemoveContact extends HomeEvent {
  final String userId;
  HomeRemoveContact(this.userId);
}

class HomeDeleteChat extends HomeEvent {
  final String chatId;
  HomeDeleteChat(this.chatId);
}
