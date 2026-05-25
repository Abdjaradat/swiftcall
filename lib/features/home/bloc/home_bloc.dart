import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/phone_contact_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_service.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<HomeLoadChats>(_onLoadChats);
    on<HomeSearchChanged>(_onSearchChanged);
    on<HomeLoadContacts>(_onLoadContacts);
    on<HomeRemoveContact>(_onRemoveContact);
    on<HomeDeleteChat>(_onDeleteChat);
  }

  Future<void> _onLoadChats(
    HomeLoadChats event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    await emit.forEach<List<ChatModel>>(
      ChatService.instance.watchChats(),
      onData: (chats) {
        final current = state is HomeLoaded ? state as HomeLoaded : null;
        return HomeLoaded(
          chats: chats,
          contacts: current?.contacts ?? [],
          phoneContacts: current?.phoneContacts ?? [],
          contactsPermissionDenied:
              current?.contactsPermissionDenied ?? false,
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

  Future<void> _onLoadContacts(
    HomeLoadContacts event,
    Emitter<HomeState> emit,
  ) async {
    final me = await AuthService.instance.getCurrentUserModel();

    // ── 1. Device contacts ────────────────────────────────────
    List<PhoneContactModel> phoneContacts = [];
    bool permDenied = false;
    List<String> devicePhones = [];

    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      permDenied = true;
    } else {
      final raw = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: true,
      );
      for (final c in raw) {
        if (c.displayName.isEmpty) continue;
        final email =
            c.emails.isNotEmpty ? c.emails.first.address.toLowerCase() : null;
        final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
        final normalized = phone != null
            ? AuthService.instance.normalizePhone(phone)
            : null;
        if (normalized != null) devicePhones.add(normalized);

        phoneContacts.add(PhoneContactModel(
          name: c.displayName,
          phone: phone,
          email: email,
          photo: c.thumbnail,
        ));
      }
    }

    // ── 2. App users matching device phones ────────────────────
    List<UserModel> matchedUsers = [];
    if (!permDenied && devicePhones.isNotEmpty) {
      try {
        matchedUsers = await AuthService.instance.getUsersByPhones(devicePhones);
      } catch (_) {
        matchedUsers = [];
      }
    }

    // Exclude self and hidden contacts
    final hidden = me?.hiddenContacts ?? [];
    matchedUsers = matchedUsers
        .where((u) => u.uid != me?.uid && !hidden.contains(u.uid))
        .toList();

    // ── 3. Emit merged state ───────────────────────────────────
    if (state is HomeLoaded) {
      emit((state as HomeLoaded).copyWith(
        contacts: matchedUsers,
        phoneContacts: phoneContacts,
        contactsPermissionDenied: permDenied,
      ));
    } else {
      emit(HomeLoaded(
        chats: const [],
        contacts: matchedUsers,
        phoneContacts: phoneContacts,
        contactsPermissionDenied: permDenied,
      ));
    }
  }

  Future<void> _onRemoveContact(
    HomeRemoveContact event,
    Emitter<HomeState> emit,
  ) async {
    await AuthService.instance.hideContact(event.userId);
    add(HomeLoadContacts());
  }

  Future<void> _onDeleteChat(
    HomeDeleteChat event,
    Emitter<HomeState> emit,
  ) async {
    await ChatService.instance.deleteChat(event.chatId);
  }

  @override
  Future<void> close() {
    return super.close();
  }
}
