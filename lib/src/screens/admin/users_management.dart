import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toast/toast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../models/users.dart';
import '../../models/errors.dart';
import '../core/contants.dart';

final usersProvider = FutureProvider.autoDispose<UserCollection>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final users = api.getUsers(page: 1);
  return users;
});

final userSearchProvider = FutureProvider.autoDispose.family<UserCollection, String>((ref, query) async {
  final api = ref.watch(apiServiceProvider);
  final users = api.getUsers(page: 1, phone: query);
  debugPrint(users.toString());
  return users;
});

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMoreUsers();
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final nextPage = _currentPage + 1;
      final newUsers = await api.getUsers(
        page: nextPage,
        phone: _searchQuery.isNotEmpty ? _searchQuery : null,
        role: _roleFilter,
      );

      ref.read(usersProvider).whenData((currentUsers) {
        final updatedMembers = [...currentUsers.member, ...newUsers.member];
        final updatedCollection = UserCollection(
          member: updatedMembers,
          totalItems: newUsers.totalItems,
          view: newUsers.view,
          search: {},
        );
        // Update the provider state (pseudo-code - would need state management adjustment)
      });

      setState(() {
        _currentPage = nextPage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more users: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ToastContext().init(context);
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSecondaryBarBackgroundColor,
        title: Text('Users Management', style: kSecondaryBarStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: kSecondaryBarActionButtonColor),
            onPressed: () => _showAddUserDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchFilterBar(ref),
          Expanded(
            child: usersAsync.when(
              data: (userCollection) => userCollection.member.isEmpty
                  ? const Center(child: Text('No users found'))
                  : _buildUsersList(userCollection),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading users: ${error.toString()}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by phone or name...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _searchQuery = _searchController.text;
                    });
                    ref.invalidate(usersProvider);
                  },
                ),
              ),
              onSubmitted: (value) {
                setState(() {
                  _searchQuery = value;
                });
                ref.invalidate(usersProvider);
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _roleFilter,
            hint: const Text('Filter by role'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All Roles')),
              DropdownMenuItem(value: 'ROLE_ADMIN', child: Text('Admin')),
              DropdownMenuItem(value: 'ROLE_DRIVER', child: Text('Driver')),
            ],
            onChanged: (value) {
              setState(() {
                _roleFilter = value;
              });
              ref.invalidate(usersProvider);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(UserCollection userCollection) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: userCollection.member.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == userCollection.member.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = userCollection.member[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: ListTile(
          title: Text(user.name ?? 'No Name'),
          subtitle:  InkWell(
            onTap: () async {
              final Uri phoneUri = Uri(scheme: 'tel', path: user.phone);
              if (await canLaunchUrl(phoneUri)) {
                await launchUrl(phoneUri);
              } else {
                Clipboard.setData(ClipboardData(text: user.phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Phone number copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              user.phone,
              style: kPrincipalTextStyle.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
                fontSize: 16,
              ),
            ),
          ),
          //Text(user.phone, style: ),
          leading: Icon(
            user.isEnabled! ? Icons.check_circle : Icons.block,
            color: user.isEnabled! ? Colors.green : Colors.red,
          ),
          /*trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
             /* Chip(
                label: Text(
                  user.roles.join(', '),
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.indigo,
              ),
              const SizedBox(width: 8),
              Icon(
                user.isEnabled! ? Icons.check_circle : Icons.block,
                color: user.isEnabled! ? Colors.green : Colors.red,
              ),*/
            ],
          ),*/
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${user.id}'),
                const SizedBox(height: 8),
                Text('Enabled: ${user.isEnabled}'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () => _showEditUserDialog(context, user),
                      child: const Text('Edit'),
                    ),
                    ElevatedButton(
                      onPressed: () => _showResetPasswordDialog(context, user),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('Reset Password'),
                    ),
                    ElevatedButton(
                      onPressed: () => _showDeleteDialog(context, user),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AddUserDialog(
        onUserAdded: () {
          ref.invalidate(usersProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User added successfully')),
          );
        },
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        user: user,
        onUserUpdated: () {
          ref.invalidate(usersProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User updated successfully')),
          );
        },
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => ResetPasswordDialog(user: user),
    );
  }

  void _showDeleteDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This action cannot be undone. This will permanently delete:'),
            const SizedBox(height: 8),
            Text('User: ${user.name} (${user.phone})'),
            const SizedBox(height: 16),
            const Text(
              'Warning: Deleting user accounts may affect system operations and historical data.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final api = ref.read(apiServiceProvider);
                await api.deleteUser(user.id!);
                ref.invalidate(usersProvider);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User deleted successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting user: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class AddUserDialog extends ConsumerStatefulWidget {
  final VoidCallback onUserAdded;
  const AddUserDialog({super.key, required this.onUserAdded});

  @override
  ConsumerState<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'ROLE_DRIVER';
  bool _isEnabled = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  if (value.length < 8) {
                    return 'Phone number must be at least 8 digits';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: const [
                  DropdownMenuItem(value: 'ROLE_ADMIN', child: Text('Admin')),
                  DropdownMenuItem(value: 'ROLE_DRIVER', child: Text('Driver')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              SwitchListTile(
                title: const Text('Enabled'),
                value: _isEnabled,
                onChanged: (value) {
                  setState(() {
                    _isEnabled = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                final api = ref.read(apiServiceProvider);
                final newUser = User(
                  phone: _phoneController.text,
                  name: _nameController.text,
                  roles: [_selectedRole],
                  isEnabled: _isEnabled,
                );
                await api.createUser(newUser);
                widget.onUserAdded();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error creating user: ${e.toString()}')),
                );
              }
            }
          },
          child: const Text('Add User'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class EditUserDialog extends ConsumerStatefulWidget {
  final User user;
  final VoidCallback onUserUpdated;
  const EditUserDialog({super.key, required this.user, required this.onUserUpdated});

  @override
  ConsumerState<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedRole;
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _selectedRole = widget.user.roles.isNotEmpty ? widget.user.roles.first : 'ROLE_DRIVER';
    _isEnabled = widget.user.isEnabled!;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: const [
                  DropdownMenuItem(value: 'ROLE_ADMIN', child: Text('Admin')),
                  DropdownMenuItem(value: 'ROLE_DRIVER', child: Text('Driver')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              SwitchListTile(
                title: const Text('Enabled'),
                value: _isEnabled,
                onChanged: (value) {
                  setState(() {
                    _isEnabled = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                final api = ref.read(apiServiceProvider);
                await api.updateUser(widget.user.id!, {
                  'name': _nameController.text,
                  'roles': [_selectedRole],
                  'isEnabled': _isEnabled,
                });
                widget.onUserUpdated();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating user: ${e.toString()}')),
                );
              }
            }
          },
          child: const Text('Update User'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class ResetPasswordDialog extends ConsumerStatefulWidget {
  final User user;
  const ResetPasswordDialog({super.key, required this.user});

  @override
  ConsumerState<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reset password for ${widget.user.name} (${widget.user.phone})'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                // This would require a backend endpoint for admin password reset
                // For now, we'll show a message indicating this feature is pending
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset functionality pending backend implementation')),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error resetting password: ${e.toString()}')),
                );
              }
            }
          },
          child: const Text('Reset Password'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}