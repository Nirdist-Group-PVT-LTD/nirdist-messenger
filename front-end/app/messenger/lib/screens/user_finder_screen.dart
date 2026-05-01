import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/profile_summary.dart';
import '../services/api_base_url.dart';
import '../services/auth_api_client.dart';
import '../services/messenger_api_client.dart';

class UserFinderScreen extends StatefulWidget {
  const UserFinderScreen({
    super.key,
    required this.session,
    required this.apiBaseUrl,
    required this.apiClient,
    required this.authApiClient,
    required this.friendIds,
    required this.onStartConversation,
    required this.onSendFriendRequest,
    this.initialQuery = '',
  });

  final AuthSession session;
  final String apiBaseUrl;
  final MessengerApiClient apiClient;
  final AuthApiClient authApiClient;
  final Set<int> friendIds;
  final Future<void> Function(ProfileSummary profile) onStartConversation;
  final Future<void> Function(ProfileSummary profile) onSendFriendRequest;
  final String initialQuery;

  @override
  State<UserFinderScreen> createState() => _UserFinderScreenState();
}

class _UserFinderScreenState extends State<UserFinderScreen> {
  late final TextEditingController _queryController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resultsSectionKey = GlobalKey();
  List<ProfileSummary> _results = <ProfileSummary>[];
  List<ProfileSummary> _directory = <ProfileSummary>[];
  bool _isLoading = false;
  bool _isLoadingDirectory = false;
  String? _errorMessage;
  String? _directoryError;
  int _requestId = 0;
  int _directoryRequestId = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    unawaited(_loadDirectory());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      _runSearch(_queryController.text);
    });
  }

  Future<void> _runSearch(String value) async {
    final query = value.trim();
    final requestId = ++_requestId;

    if (query.isEmpty) {
      setState(() {
        _results = <ProfileSummary>[];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _searchWithFallback(query);

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _results = results;
        _isLoading = false;
      });

      if (query.isNotEmpty) {
        _scrollToResults();
      }
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _results = <ProfileSummary>[];
        _isLoading = false;
        _errorMessage = error is MessengerApiException ? error.message : 'Unable to search users.';
      });
    }
  }

  Future<void> _loadDirectory() async {
    final requestId = ++_directoryRequestId;

    if (mounted) {
      setState(() {
        _isLoadingDirectory = true;
        _directoryError = null;
      });
    }

    try {
      final directory = await widget.apiClient.listProfiles(widget.session.profile.vId);

      if (!mounted || requestId != _directoryRequestId) {
        return;
      }

      setState(() {
        _directory = directory;
        _isLoadingDirectory = false;
      });

      if (_queryController.text.trim().isNotEmpty) {
        _scrollToResults();
      }
    } catch (error) {
      if (!mounted || requestId != _directoryRequestId) {
        return;
      }

      setState(() {
        _directory = <ProfileSummary>[];
        _isLoadingDirectory = false;
        _directoryError = error is MessengerApiException ? error.message : 'Unable to load users.';
      });
    }
  }

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final context = _resultsSectionKey.currentContext;
      if (context == null) {
        return;
      }

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        alignment: 0.0,
      );
    });
  }

  Future<List<ProfileSummary>> _searchWithFallback(String query) async {
    try {
      final results = await widget.apiClient.searchProfiles(
        query: query,
        excludeUserId: widget.session.profile.vId,
      );

      if (results.isNotEmpty || !_looksLikePhoneNumber(query)) {
        return results;
      }
    } catch (error) {
      if (!_looksLikePhoneNumber(query)) {
        rethrow;
      }
    }

    if (_looksLikePhoneNumber(query)) {
      final profile = await widget.authApiClient.lookupPhoneNumber(query);
      if (profile.vId != widget.session.profile.vId) {
        return <ProfileSummary>[profile];
      }
    }

    return widget.apiClient.listProfiles(widget.session.profile.vId);
  }

  bool _looksLikePhoneNumber(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9+]'), '');
    return normalized.contains(RegExp(r'\d{7,}'));
  }

  String _requestUrl(String query) {
    final normalizedBaseUrl = normalizeApiBaseUrl(widget.apiBaseUrl);

    return Uri.parse('$normalizedBaseUrl/social/profiles/search').replace(
      queryParameters: <String, String>{
        'q': query,
        'excludeUserId': widget.session.profile.vId.toString(),
      },
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim();
    final requestUrl = query.isEmpty ? null : _requestUrl(query);
    final hasQuery = query.isNotEmpty;
    final displayedResults = hasQuery
        ? (_results.isNotEmpty ? _results : _directory)
        : _directory;
    final isShowingDirectoryFallback = hasQuery && _results.isEmpty && _directory.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF08111A), Color(0xFF0A1720), Color(0xFF061017)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Find users', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Search by name, username, VId, phone number, or email. Use a live Render API call.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1720),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _queryController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runSearch,
                  onChanged: (_) {
                    setState(() {});
                    _scheduleSearch();
                  },
                  decoration: InputDecoration(
                    labelText: 'Search users',
                    hintText: 'name, username, VId, phone, email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _queryController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _queryController.clear();
                              setState(() {
                                _results = <ProfileSummary>[];
                                _errorMessage = null;
                              });
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: () {
                      _queryController.text = '+9779821663633';
                      _queryController.selection = TextSelection.fromPosition(TextPosition(offset: _queryController.text.length));
                      setState(() {});
                        _scheduleSearch();
                    },
                    child: const Text('Try +9779821663633'),
                  ),
                  FilledButton.tonal(
                    onPressed: query.isEmpty ? null : () => _runSearch(_queryController.text),
                    child: const Text('Search now'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (requestUrl != null)
                _InfoCard(
                  title: 'Request URL',
                  child: Text(requestUrl, softWrap: true),
                ),
              if (_isLoading) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_isLoadingDirectory && !hasQuery) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Search failed',
                  child: Text(_errorMessage!),
                ),
              ],
              if (_directoryError != null && _directory.isEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Users unavailable',
                  child: Text(_directoryError!),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                key: _resultsSectionKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Results', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (isShowingDirectoryFallback)
                      _InfoCard(
                        title: 'No direct matches found',
                        child: Text(
                          'Showing other users from the loaded directory instead.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    if (!_isLoading && !_isLoadingDirectory && displayedResults.isEmpty)
                      _InfoCard(
                        title: 'No users found',
                        child: Text(
                          query.isEmpty
                              ? 'Users will appear here after the directory loads.'
                              : 'Try another name, username, phone number, or email.',
                        ),
                      )
                    else
                      ...displayedResults.map(
                        (profile) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ResultTile(
                            profile: profile,
                            isFriend: widget.friendIds.contains(profile.vId),
                            onPrimary: () {
                              if (widget.friendIds.contains(profile.vId)) {
                                widget.onStartConversation(profile);
                              } else {
                                widget.onSendFriendRequest(profile);
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.profile,
    required this.isFriend,
    required this.onPrimary,
  });

  final ProfileSummary profile;
  final bool isFriend;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            child: Text(_initials(profile.displayLabel)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.displayLabel, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(profile.phoneNumber ?? profile.email ?? '@${profile.username ?? 'unknown'}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onPrimary,
            icon: Icon(isFriend ? Icons.message_outlined : Icons.person_add_alt_1),
            label: Text(isFriend ? 'Chat' : 'Request'),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return 'N';
    }

    if (parts.length == 1) {
      final word = parts.first;
      return word.length >= 2 ? word.substring(0, 2).toUpperCase() : word.substring(0, 1).toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}