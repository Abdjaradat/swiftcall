import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_service.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<HomeLoadChats>(_onLoadChats);
    on<HomeSearchChanged>(_onSearchChanged);
    on<HomeLoadUsers>(_onLoadUsers);
    on<HomeSendRequest>(_onSendRequest);
    on<HomeAcceptRequest>(_onAcceptRequest);
    on<HomeRejectRequest>(_onRejectRequest);
    on<HomeCancelRequest>(_onCancelRequest);
    on<HomeRemoveFriend>(_onRemoveFriend);
    on<HomeDeleteChat>(_onDeleteChat);
  }

  Future<void> _onLoadChats(
    HomeLoadChats event,
    Emitter<HomeState> emit,
  ) async {
    // Only show loading spinner on first load (no existing chats yet).
    if (state is! HomeLoaded) emit(HomeLoading());
    await emit.forEach<List<ChatModel>>(
      ChatService.instance.watchChats(),
      onData: (chats) {
        final current = state is HomeLoaded ? state as HomeLoaded : null;
        return HomeLoaded(
          chats: chats,
          contacts: current?.contacts ?? [],
          myUid: current?.myUid ?? '',
          searchQuery: current?.searchQuery ?? '',
        );
      },
      onError: (_, __) => HomeError('فشل تحميل المحادثات'),
    );
  }

  void _onSearchChanged(HomeSearchChanged event, Emitter<HomeState> emit) {
    if (state is HomeLoaded) {
      emit((state as HomeLoaded).copyWith(searchQuery: event.query));
    }
  }

  Future<void> _onLoadUsers(
    HomeLoadUsers event,
    Emitter<HomeState> emit,
  ) async {
    // Auth guard: ensure user is logged in before querying Firestore
    final myUid = AuthService.instance.currentUserId;
    if (myUid == null || myUid.isEmpty) {
      print('HomeBloc._onLoadUsers: User not authenticated, skipping');
      return;
    }

    try {
      final allUsers = await AuthService.instance.getAllUsers();
      final others =
          allUsers.where((u) => u.uid != myUid).toList();

      if (state is HomeLoaded) {
        emit((state as HomeLoaded).copyWith(
          contacts: others,
          myUid: myUid,
        ));
      } else {
        emit(HomeLoaded(
          chats: const [],
          contacts: others,
          myUid: myUid,
        ));
      }
    } catch (e, stack) {
      print('HomeBloc._onLoadUsers ERROR: $e');
      print('STACK: $stack');
      if (state is HomeLoaded) {
        emit((state as HomeLoaded).copyWith(contacts: []));
      }
    }
  }

  Future<void> _onSendRequest(
    HomeSendRequest event,
    Emitter<HomeState> emit,
  ) async {
    await AuthService.instance.sendFriendRequest(event.userId);
    add(HomeLoadUsers());
  }

  Future<void> _onAcceptRequest(
    HomeAcceptRequest event,
    Emitter<HomeState> emit,
  ) async {
    await AuthService.instance.acceptFriendRequest(event.userId);
    add(HomeLoadUsers());
    add(HomeLoadChats());
  }

  Future<void> _onRejectRequest(
    HomeRejectRequest event,
    Emitter<HomeState> emit,
  ) async {
    await AuthService.instance.rejectFriendRequest(event.userId);
    add(HomeLoadUsers());
  }

  Future<void> _onCancelRequest(
    HomeCancelRequest event,
    Emitter<HomeState> emit,
  ) async {
    await AuthService.instance.cancelFriendRequest(event.userId);
    add(HomeLoadUsers());
  }

  Future<void> _onRemoveFriend(
    HomeRemoveFriend event,
    Emitter<HomeState> emit,
  ) async {
    await AuthService.instance.removeFriend(event.userId);
    add(HomeLoadUsers());
    add(HomeLoadChats());
  }

  Future<void> _onDeleteChat(
    HomeDeleteChat event,
    Emitter<HomeState> emit,
  ) async {
    await ChatService.instance.deleteChat(event.chatId);
  }

}
