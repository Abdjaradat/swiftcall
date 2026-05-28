part of 'home_bloc.dart';

abstract class HomeEvent {}

class HomeLoadChats extends HomeEvent {}

class HomeSearchChanged extends HomeEvent {
  final String query;
  HomeSearchChanged(this.query);
}

class HomeLoadUsers extends HomeEvent {}

class HomeSendRequest extends HomeEvent {
  final String userId;
  HomeSendRequest(this.userId);
}

class HomeAcceptRequest extends HomeEvent {
  final String userId;
  HomeAcceptRequest(this.userId);
}

class HomeRejectRequest extends HomeEvent {
  final String userId;
  HomeRejectRequest(this.userId);
}

class HomeCancelRequest extends HomeEvent {
  final String userId;
  HomeCancelRequest(this.userId);
}

class HomeRemoveFriend extends HomeEvent {
  final String userId;
  HomeRemoveFriend(this.userId);
}

class HomeDeleteChat extends HomeEvent {
  final String chatId;
  HomeDeleteChat(this.chatId);
}
