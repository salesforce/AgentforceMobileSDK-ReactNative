/*
 * Copyright (c) 2020-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided
 * that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the
 * following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
 * the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or
 * promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import React from 'react';
import {
    StyleSheet,
    Text,
    View,
    FlatList,
    TouchableOpacity,
    Modal,
    Alert,
    NativeModules,
    NativeEventEmitter,
    Image,
    TextInput,
    Clipboard,
    ScrollView,
} from 'react-native';

import { NavigationContainer, RouteProp } from '@react-navigation/native';
import { createStackNavigator, StackNavigationProp } from '@react-navigation/stack';
import { oauth, net } from 'react-native-force';

interface Agent {
    id: string,
    label: string,
    isDefault: boolean
}

type RootStackParamList = {
    'React Native Agentforce': undefined;
    ContactDetail: { contact: Record };
    Settings: {
        agents: Agent[];
        orgId: string;
        userContext: string;
        onSave: (agents: Agent[], orgId: string, userContext: string) => void;
    };
};

interface AgentforceManagerType {
    initializeAgentforce(config: {
        agents: Array<{ id: string, label: string, isDefault: boolean }>,
        orgId: string,
        endpoint: string
    }): Promise<{ success: boolean }>;

    presentAgentforceChatView(agentId: string, userContext: string): Promise<{ success: boolean }>;

    dismissAgentforceChatView(): Promise<{ success: boolean }>;

    showLandingPage(): Promise<{ success: boolean }>;
}

const { AgentforceManager } = NativeModules as { AgentforceManager: AgentforceManagerType };

interface Response {
    records: Record[]
}

interface Record {
    Id: string,
    Name: string,
    Email?: string,
    Phone?: string,
    MobilePhone?: string,
    Title?: string,
    Department?: string,
    Account?: { Name: string }
}

interface Props {
    navigation: StackNavigationProp<RootStackParamList, 'React Native Agentforce'>;
}

interface State {
    data: Record[],
    showAgentforceModal: boolean,
    agentforceInitialized: boolean,
    agents: Agent[],
    isAddingAgent: boolean,
    newAgentId: string,
    newAgentLabel: string,
    editingAgentIndex: number | null,
    orgId: string,
    userContext: string,
    isUserContextEditable: boolean
}

class ContactListScreen extends React.Component<Props, State> {
    private eventEmitter: NativeEventEmitter;
    private navigationEventSubscription: any;

    constructor(props: Props) {
        super(props);
        this.state = {
            data: [],
            showAgentforceModal: false,
            agentforceInitialized: false,
            agents: [
                { id: "0XxEE0000001fkH0AQ", label: "Default Agent", isDefault: true }
            ],
            isAddingAgent: false,
            newAgentId: "",
            newAgentLabel: "",
            editingAgentIndex: null,
            orgId: "00DEE000000XQRx",
            userContext: "",
            isUserContextEditable: false
        };
        this.eventEmitter = new NativeEventEmitter(AgentforceManager);
    }

    componentDidMount() {
        var that = this;

        // Set up header buttons
        this.props.navigation.setOptions({
            headerLeft: () => (
                <TouchableOpacity
                    onPress={this.navigateToLandingPage}
                    style={{ marginLeft: 15 }}
                >
                    <Text style={{ fontSize: 16, color: '#0070f3', fontWeight: '600' }}>Home</Text>
                </TouchableOpacity>
            ),
            headerRight: () => (
                <TouchableOpacity
                    onPress={this.navigateToSettings}
                    style={{ marginRight: 15 }}
                >
                    <Text style={{ fontSize: 16, color: '#0070f3', fontWeight: '600' }}>Settings</Text>
                </TouchableOpacity>
            ),
        });

        // Set up navigation event listener
        this.navigationEventSubscription = this.eventEmitter.addListener(
            'agentforceNavigation',
            (event: { id: string; type?: string }) => {
                // Search for the contact in our data
                const contact = this.state.data.find((c) => c.Id === event.id);

                // Check if this is a Contact record
                if (event.type === 'Contact') {
                    if (contact) {
                        // Dismiss the Agentforce chat view, then navigate
                        AgentforceManager.dismissAgentforceChatView()
                            .then(() => {
                                this.props.navigation.navigate('ContactDetail', { contact });
                            })
                            .catch((error: any) => {
                                console.error('Failed to dismiss Agentforce chat:', error);
                            });
                    } else {
                        Alert.alert('Contact Not Found', 'This contact is not in the loaded list.');
                    }
                }
            }
        );

        oauth.getAuthCredentials(
            () => {
                that.fetchData();
                that.initializeAgentforce();
            }, // already logged in
            () => {
                oauth.authenticate(
                    () => {
                        that.fetchData();
                        that.initializeAgentforce();
                    },
                    (error) => console.log('Failed to authenticate:' + error)
                );
            });
    }

    fetchData() {
        var that = this;
        net.query('SELECT Id, Name, Email, Phone, MobilePhone, Title, Department, Account.Name FROM Contact LIMIT 100',
            (response: Response) => that.setState({ data: response.records }),
            (error) => console.log('Failed to query:' + error)
        );
    }

    initializeAgentforce() {
        oauth.getAuthCredentials(
            () => {
                // Get current user info from SalesforceSDK
                net.query('SELECT Id, Name FROM Organization LIMIT 1',
                    (response: any) => {
                        const orgId = response.records[0]?.Id;
                        if (orgId) {
                            this.setState({ orgId: orgId });
                            const config = {
                                agents: this.state.agents,
                                orgId: orgId,
                                endpoint: "https://YOUR_DOMAIN.my.salesforce.com" // Replace with your Salesforce domain
                            };

                            AgentforceManager.initializeAgentforce(config)
                                .then(() => {
                                    console.log('Agentforce initialized successfully');
                                    this.setState({ agentforceInitialized: true });
                                })
                                .catch((error: any) => {
                                    console.error('Failed to initialize Agentforce:', error);
                                    Alert.alert('Initialization Error', 'Failed to initialize Agentforce: ' + error.message);
                                });
                        } else {
                            console.error('Could not get organization ID');
                        }
                    },
                    (error) => console.error('Failed to get organization info:', error)
                );
            },
            () => console.log('User not authenticated')
        );
    }

    openAgentforceModal = () => {
        this.setState({ showAgentforceModal: true });
    }

    closeAgentforceModal = () => {
        this.setState({ showAgentforceModal: false });
    }

    toggleUserContextEdit = () => {
        this.setState({ isUserContextEditable: !this.state.isUserContextEditable });
    }

    handleUserContextChange = (text: string) => {
        this.setState({ userContext: text });
    }

    reinitializeAgentforce = () => {
        if (!this.state.orgId) {
            console.log('Cannot reinitialize: orgId not available');
            return;
        }

        const config = {
            agents: this.state.agents,
            orgId: this.state.orgId,
            endpoint: "https://YOUR_DOMAIN.my.salesforce.com"
        };

        AgentforceManager.initializeAgentforce(config)
            .then(() => {
                console.log('Agentforce re-initialized with updated agents');
            })
            .catch((error: any) => {
                console.error('Failed to re-initialize Agentforce:', error);
            });
    }

    startAddingAgent = () => {
        this.setState({ isAddingAgent: true, newAgentId: "", newAgentLabel: "" });
    }

    cancelAddingAgent = () => {
        this.setState({ isAddingAgent: false, newAgentId: "", newAgentLabel: "", editingAgentIndex: null });
    }

    saveNewAgent = () => {
        if (!this.state.newAgentId || !this.state.newAgentLabel) {
            Alert.alert('Error', 'Please enter both Agent ID and Label');
            return;
        }

        const newAgent: Agent = {
            id: this.state.newAgentId,
            label: this.state.newAgentLabel,
            isDefault: this.state.agents.length === 0
        };

        if (this.state.editingAgentIndex !== null) {
            // Editing existing agent
            const updatedAgents = [...this.state.agents];
            updatedAgents[this.state.editingAgentIndex] = { ...newAgent, isDefault: updatedAgents[this.state.editingAgentIndex].isDefault };
            this.setState({
                agents: updatedAgents,
                isAddingAgent: false,
                newAgentId: "",
                newAgentLabel: "",
                editingAgentIndex: null
            }, () => {
                this.reinitializeAgentforce();
            });
        } else {
            // Adding new agent
            this.setState({
                agents: [...this.state.agents, newAgent],
                isAddingAgent: false,
                newAgentId: "",
                newAgentLabel: ""
            }, () => {
                this.reinitializeAgentforce();
            });
        }
    }

    editAgent = (index: number) => {
        const agent = this.state.agents[index];
        this.setState({
            isAddingAgent: true,
            newAgentId: agent.id,
            newAgentLabel: agent.label,
            editingAgentIndex: index
        });
    }

    deleteAgent = (index: number) => {
        if (this.state.agents.length === 1) {
            Alert.alert('Error', 'Cannot delete the last agent');
            return;
        }

        const updatedAgents = this.state.agents.filter((_, i) => i !== index);
        // If we deleted the default agent, make the first one default
        if (this.state.agents[index].isDefault && updatedAgents.length > 0) {
            updatedAgents[0].isDefault = true;
        }
        this.setState({ agents: updatedAgents }, () => {
            this.reinitializeAgentforce();
        });
    }

    setDefaultAgent = (index: number) => {
        const updatedAgents = this.state.agents.map((agent, i) => ({
            ...agent,
            isDefault: i === index
        }));
        this.setState({ agents: updatedAgents }, () => {
            this.reinitializeAgentforce();
        });
    }

    launchAgentforceSDK = (agentId?: string) => {
        if (!this.state.agentforceInitialized) {
            console.log('Agentforce is not initialized yet. Please wait a moment and try again.');
            return;
        }

        // If agentId is provided, use it; otherwise pass empty string to show agent picker
        const selectedAgentId = agentId || "";
        const context = this.state.userContext || "";  // Ensure it's never undefined

        console.log('Calling presentAgentforceChatView with agentId:', selectedAgentId, 'context:', context);

        AgentforceManager.presentAgentforceChatView(selectedAgentId, context)
            .then(() => {
                console.log('Agentforce chat view presented successfully');
            })
            .catch((error: any) => {
                console.error('Failed to present Agentforce chat:', error);
            });
    }

    navigateToSettings = () => {
        this.props.navigation.navigate('Settings', {
            agents: this.state.agents,
            orgId: this.state.orgId,
            userContext: this.state.userContext,
            onSave: (agents: Agent[], orgId: string, userContext: string) => {
                this.setState({ agents, orgId, userContext }, () => {
                    this.reinitializeAgentforce();
                });
            }
        });
    }

    navigateToLandingPage = () => {
        AgentforceManager.showLandingPage()
            .then(() => {
                console.log('Navigated to landing page successfully');
            })
            .catch((error: any) => {
                console.error('Failed to navigate to landing page:', error);
                Alert.alert('Error', 'Failed to navigate to landing page: ' + error.message);
            });
    }

    componentWillUnmount() {
        // Clean up the navigation event listener
        if (this.navigationEventSubscription) {
            this.navigationEventSubscription.remove();
        }
    }

    renderContactItem = ({ item }: { item: Record }) => (
        <TouchableOpacity
            style={styles.contactCard}
            onPress={() => this.props.navigation.navigate('ContactDetail', { contact: item })}
        >
            <View style={styles.contactAvatar}>
                <Text style={styles.contactAvatarText}>
                    {item.Name.substring(0, 2).toUpperCase()}
                </Text>
            </View>
            <View style={styles.contactInfo}>
                <Text style={styles.contactName}>{item.Name}</Text>
                {item.Title && <Text style={styles.contactTitle}>{item.Title}</Text>}
                {item.Account?.Name && <Text style={styles.contactCompany}>{item.Account.Name}</Text>}
            </View>
            <Text style={styles.contactChevron}>›</Text>
        </TouchableOpacity>
    )

    renderListHeader = () => (
        <View style={styles.listHeader}>
            <Text style={styles.listHeaderTitle}>Contacts</Text>
            <Text style={styles.listHeaderSubtitle}>{this.state.data.length} contacts</Text>
        </View>
    )

    render() {
        // NOTE: Contact list code is preserved below but not displayed
        // Uncomment the FlatList section to show contacts in the future

        return (
            <View style={styles.container}>
                <ScrollView
                    contentContainerStyle={styles.welcomeContainer}
                    showsVerticalScrollIndicator={false}
                >
                    <View style={styles.welcomeContent}>
                        <View style={styles.iconContainer}>
                            <Image
                                source={require('./agentforce-icon.png')}
                                style={styles.welcomeIcon}
                            />
                        </View>

                        <Text style={styles.welcomeTitle}>Welcome to Agentforce</Text>
                        <Text style={styles.welcomeSubtitle}>
                            Your intelligent assistant is ready to help
                        </Text>

                        <View style={styles.featureCard}>
                            <Text style={styles.featureEmoji}>💬</Text>
                            <Text style={styles.featureTitle}>Chat Support</Text>
                            <Text style={styles.featureDescription}>
                                Get instant help with your questions
                            </Text>
                        </View>

                        <View style={styles.featureCard}>
                            <Text style={styles.featureEmoji}>⚡</Text>
                            <Text style={styles.featureTitle}>Quick Responses</Text>
                            <Text style={styles.featureDescription}>
                                Fast and accurate answers anytime
                            </Text>
                        </View>

                        <View style={styles.featureCard}>
                            <Text style={styles.featureEmoji}>🎯</Text>
                            <Text style={styles.featureTitle}>Smart Assistance</Text>
                            <Text style={styles.featureDescription}>
                                Powered by AI to help you succeed
                            </Text>
                        </View>

                        {!this.state.agentforceInitialized && (
                            <View style={styles.statusContainer}>
                                <Text style={styles.statusText}>Initializing Agentforce...</Text>
                            </View>
                        )}
                    </View>
                </ScrollView>

                {/* Agentforce Chat Button - Floating Action Button */}
                <TouchableOpacity
                    style={[styles.agentforceButton, !this.state.agentforceInitialized && styles.agentforceButtonDisabled]}
                    onPress={() => {
                        // Pass the default agent ID explicitly
                        const defaultAgent = this.state.agents.find(a => a.isDefault);
                        this.launchAgentforceSDK(defaultAgent?.id);
                    }}
                    disabled={!this.state.agentforceInitialized}
                >
                    {this.state.agentforceInitialized ? (
                        <Image
                            source={require('./agentforce-icon.png')}
                            style={styles.agentforceButtonIcon}
                        />
                    ) : (
                        <Text style={styles.agentforceButtonText}>Initializing...</Text>
                    )}
                </TouchableOpacity>
                {/* Contact List - Hidden but code preserved for future use */}
                {/*
                <FlatList
                    style={styles.contactList}
                    data={this.state.data}
                    renderItem={this.renderContactItem}
                    keyExtractor={(item, index) => 'key_' + index}
                    ListHeaderComponent={this.renderListHeader}
                    contentContainerStyle={styles.listContent}
                />
                */}
            </View>
        );
    }
}

interface SettingsProps {
    navigation: StackNavigationProp<RootStackParamList, 'Settings'>;
    route: RouteProp<RootStackParamList, 'Settings'>;
}

interface SettingsState {
    agents: Agent[];
    orgId: string;
    userContext: string;
    isAddingAgent: boolean;
    newAgentId: string;
    newAgentLabel: string;
    editingAgentIndex: number | null;
    isUserContextEditable: boolean;
}

class SettingsScreen extends React.Component<SettingsProps, SettingsState> {
    constructor(props: SettingsProps) {
        super(props);
        this.state = {
            agents: props.route.params.agents,
            orgId: props.route.params.orgId,
            userContext: props.route.params.userContext,
            isAddingAgent: false,
            newAgentId: "",
            newAgentLabel: "",
            editingAgentIndex: null,
            isUserContextEditable: false
        };
    }

    componentWillUnmount() {
        // Save settings when leaving the screen
        this.props.route.params.onSave(
            this.state.agents,
            this.state.orgId,
            this.state.userContext
        );
    }

    startAddingAgent = () => {
        this.setState({ isAddingAgent: true, newAgentId: "", newAgentLabel: "" });
    }

    cancelAddingAgent = () => {
        this.setState({ isAddingAgent: false, newAgentId: "", newAgentLabel: "", editingAgentIndex: null });
    }

    saveNewAgent = () => {
        if (!this.state.newAgentId || !this.state.newAgentLabel) {
            Alert.alert('Error', 'Please enter both Agent ID and Label');
            return;
        }

        const newAgent: Agent = {
            id: this.state.newAgentId,
            label: this.state.newAgentLabel,
            isDefault: this.state.agents.length === 0
        };

        if (this.state.editingAgentIndex !== null) {
            const updatedAgents = [...this.state.agents];
            updatedAgents[this.state.editingAgentIndex] = { ...newAgent, isDefault: updatedAgents[this.state.editingAgentIndex].isDefault };
            this.setState({
                agents: updatedAgents,
                isAddingAgent: false,
                newAgentId: "",
                newAgentLabel: "",
                editingAgentIndex: null
            });
        } else {
            this.setState({
                agents: [...this.state.agents, newAgent],
                isAddingAgent: false,
                newAgentId: "",
                newAgentLabel: ""
            });
        }
    }

    editAgent = (index: number) => {
        const agent = this.state.agents[index];
        this.setState({
            isAddingAgent: true,
            newAgentId: agent.id,
            newAgentLabel: agent.label,
            editingAgentIndex: index
        });
    }

    deleteAgent = (index: number) => {
        if (this.state.agents.length === 1) {
            Alert.alert('Error', 'Cannot delete the last agent');
            return;
        }

        const updatedAgents = this.state.agents.filter((_, i) => i !== index);
        if (this.state.agents[index].isDefault && updatedAgents.length > 0) {
            updatedAgents[0].isDefault = true;
        }
        this.setState({ agents: updatedAgents });
    }

    setDefaultAgent = (index: number) => {
        const updatedAgents = this.state.agents.map((agent, i) => ({
            ...agent,
            isDefault: i === index
        }));
        this.setState({ agents: updatedAgents });
    }

    toggleUserContextEdit = () => {
        this.setState({ isUserContextEditable: !this.state.isUserContextEditable });
    }

    handleUserContextChange = (text: string) => {
        this.setState({ userContext: text });
    }

    render() {
        return (
            <ScrollView style={styles.settingsContainer}>
                <View style={styles.agentsContainer}>
                    <Text style={styles.agentsLabel}>Agents:</Text>
                    {this.state.agents.map((agent, index) => (
                        <View key={index} style={styles.agentRow}>
                            <View style={styles.agentInfo}>
                                <Text style={styles.agentLabel}>{agent.label}</Text>
                                <Text style={styles.agentId}>{agent.id}</Text>
                                {agent.isDefault && <Text style={styles.defaultBadge}>DEFAULT</Text>}
                            </View>
                            <View style={styles.agentActions}>
                                {!agent.isDefault && (
                                    <TouchableOpacity
                                        style={styles.actionButton}
                                        onPress={() => this.setDefaultAgent(index)}
                                    >
                                        <Text style={styles.actionButtonText}>Set Default</Text>
                                    </TouchableOpacity>
                                )}
                                <TouchableOpacity
                                    style={styles.actionButton}
                                    onPress={() => this.editAgent(index)}
                                >
                                    <Text style={styles.actionButtonText}>Edit</Text>
                                </TouchableOpacity>
                                {this.state.agents.length > 1 && (
                                    <TouchableOpacity
                                        style={styles.deleteButton}
                                        onPress={() => this.deleteAgent(index)}
                                    >
                                        <Text style={styles.deleteButtonText}>Delete</Text>
                                    </TouchableOpacity>
                                )}
                            </View>
                        </View>
                    ))}

                    {this.state.isAddingAgent ? (
                        <View style={styles.addAgentForm}>
                            <TextInput
                                style={styles.input}
                                value={this.state.newAgentLabel}
                                onChangeText={(text) => this.setState({ newAgentLabel: text })}
                                placeholder="Agent Label"
                                placeholderTextColor="#999"
                            />
                            <TextInput
                                style={styles.input}
                                value={this.state.newAgentId}
                                onChangeText={(text) => this.setState({ newAgentId: text })}
                                placeholder="Agent ID"
                                placeholderTextColor="#999"
                            />
                            <View style={styles.formButtons}>
                                <TouchableOpacity style={styles.saveButton} onPress={this.saveNewAgent}>
                                    <Text style={styles.saveButtonText}>Save</Text>
                                </TouchableOpacity>
                                <TouchableOpacity style={styles.cancelButton} onPress={this.cancelAddingAgent}>
                                    <Text style={styles.cancelButtonText}>Cancel</Text>
                                </TouchableOpacity>
                            </View>
                        </View>
                    ) : (
                        <TouchableOpacity style={styles.addButton} onPress={this.startAddingAgent}>
                            <Text style={styles.addButtonText}>+ Add Agent</Text>
                        </TouchableOpacity>
                    )}
                </View>

                <View style={styles.orgIdContainer}>
                    <Text style={styles.orgIdLabel}>Organization ID:</Text>
                    <Text style={styles.orgIdDisplay}>
                        {this.state.orgId || 'Not available'}
                    </Text>
                </View>

                <View style={styles.userContextContainer}>
                    <Text style={styles.userContextLabel}>Record ID:</Text>
                    {this.state.isUserContextEditable ? (
                        <View style={styles.userContextInputRow}>
                            <TextInput
                                style={styles.userContextInput}
                                value={this.state.userContext}
                                onChangeText={this.handleUserContextChange}
                                placeholder="Enter Salesforce Record ID"
                                placeholderTextColor="#999"
                            />
                            <TouchableOpacity
                                style={styles.editButton}
                                onPress={this.toggleUserContextEdit}
                            >
                                <Text style={styles.editButtonText}>✓</Text>
                            </TouchableOpacity>
                        </View>
                    ) : (
                        <View style={styles.userContextDisplayRow}>
                            <Text style={styles.userContextDisplay}>
                                {this.state.userContext || 'No record ID set'}
                            </Text>
                            <TouchableOpacity
                                style={styles.editButton}
                                onPress={this.toggleUserContextEdit}
                            >
                                <Text style={styles.editButtonText}>✎</Text>
                            </TouchableOpacity>
                        </View>
                    )}
                </View>
            </ScrollView>
        );
    }
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#f8f9fa',
    },
    welcomeContainer: {
        flexGrow: 1,
        padding: 20,
        paddingTop: 40,
    },
    welcomeContent: {
        alignItems: 'center',
        justifyContent: 'center',
    },
    iconContainer: {
        width: 120,
        height: 120,
        borderRadius: 60,
        backgroundColor: 'white',
        justifyContent: 'center',
        alignItems: 'center',
        marginBottom: 30,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.1,
        shadowRadius: 8,
        elevation: 5,
    },
    welcomeIcon: {
        width: 80,
        height: 80,
        resizeMode: 'contain',
    },
    welcomeTitle: {
        fontSize: 32,
        fontWeight: 'bold',
        color: '#212529',
        marginBottom: 12,
        textAlign: 'center',
    },
    welcomeSubtitle: {
        fontSize: 18,
        color: '#6c757d',
        textAlign: 'center',
        marginBottom: 40,
        paddingHorizontal: 20,
    },
    featureCard: {
        backgroundColor: 'white',
        borderRadius: 16,
        padding: 24,
        marginBottom: 16,
        width: '100%',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.08,
        shadowRadius: 8,
        elevation: 3,
    },
    featureEmoji: {
        fontSize: 32,
        marginBottom: 12,
    },
    featureTitle: {
        fontSize: 20,
        fontWeight: '600',
        color: '#212529',
        marginBottom: 8,
    },
    featureDescription: {
        fontSize: 15,
        color: '#6c757d',
        lineHeight: 22,
    },
    statusContainer: {
        marginTop: 20,
        padding: 16,
        backgroundColor: '#e7f3ff',
        borderRadius: 12,
        width: '100%',
    },
    statusText: {
        fontSize: 14,
        color: '#0070f3',
        textAlign: 'center',
        fontWeight: '500',
    },
    contactList: {
        flex: 1,
        backgroundColor: '#f8f9fa',
    },
    listContent: {
        paddingBottom: 100,
    },
    listHeader: {
        backgroundColor: 'white',
        paddingHorizontal: 20,
        paddingTop: 20,
        paddingBottom: 15,
        borderBottomWidth: 1,
        borderBottomColor: '#e9ecef',
    },
    listHeaderTitle: {
        fontSize: 28,
        fontWeight: 'bold',
        color: '#212529',
        marginBottom: 4,
    },
    listHeaderSubtitle: {
        fontSize: 14,
        color: '#6c757d',
    },
    contactCard: {
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: 'white',
        padding: 15,
        marginHorizontal: 15,
        marginTop: 10,
        borderRadius: 12,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.1,
        shadowRadius: 2,
        elevation: 2,
    },
    contactAvatar: {
        width: 50,
        height: 50,
        borderRadius: 25,
        backgroundColor: '#0070f3',
        justifyContent: 'center',
        alignItems: 'center',
        marginRight: 15,
    },
    contactAvatarText: {
        color: 'white',
        fontSize: 18,
        fontWeight: '600',
    },
    contactInfo: {
        flex: 1,
    },
    contactName: {
        fontSize: 17,
        fontWeight: '600',
        color: '#212529',
        marginBottom: 3,
    },
    contactTitle: {
        fontSize: 14,
        color: '#6c757d',
        marginBottom: 2,
    },
    contactCompany: {
        fontSize: 13,
        color: '#868e96',
    },
    contactChevron: {
        fontSize: 24,
        color: '#ced4da',
        fontWeight: '300',
    },
    settingsContainer: {
        flex: 1,
        backgroundColor: 'white',
        padding: 15,
    },
    item: {
        padding: 10,
        borderBottomWidth: 1,
        borderBottomColor: '#e0e0e0',
        backgroundColor: 'white',
    },
    itemText: {
        fontSize: 18,
        color: '#212529',
    },
    agentsContainer: {
        backgroundColor: '#f8f9fa',
        padding: 15,
        marginTop: 10,
        marginHorizontal: 15,
        borderRadius: 8,
        borderWidth: 1,
        borderColor: '#e9ecef',
    },
    agentsLabel: {
        fontSize: 16,
        fontWeight: '600',
        color: '#343a40',
        marginBottom: 12,
    },
    agentRow: {
        backgroundColor: 'white',
        padding: 12,
        borderRadius: 6,
        marginBottom: 8,
        borderWidth: 1,
        borderColor: '#dee2e6',
    },
    agentInfo: {
        marginBottom: 8,
    },
    agentLabel: {
        fontSize: 16,
        fontWeight: '600',
        color: '#212529',
        marginBottom: 4,
    },
    agentId: {
        fontSize: 12,
        color: '#6c757d',
        fontFamily: 'monospace',
    },
    defaultBadge: {
        fontSize: 10,
        fontWeight: 'bold',
        color: '#0070f3',
        marginTop: 4,
    },
    agentActions: {
        flexDirection: 'row',
        gap: 8,
    },
    actionButton: {
        backgroundColor: '#0070f3',
        paddingHorizontal: 12,
        paddingVertical: 6,
        borderRadius: 4,
    },
    actionButtonText: {
        color: 'white',
        fontSize: 12,
        fontWeight: '600',
    },
    deleteButton: {
        backgroundColor: '#dc3545',
        paddingHorizontal: 12,
        paddingVertical: 6,
        borderRadius: 4,
    },
    deleteButtonText: {
        color: 'white',
        fontSize: 12,
        fontWeight: '600',
    },
    addButton: {
        backgroundColor: '#28a745',
        padding: 12,
        borderRadius: 6,
        alignItems: 'center',
        marginTop: 8,
    },
    addButtonText: {
        color: 'white',
        fontSize: 14,
        fontWeight: '600',
    },
    addAgentForm: {
        backgroundColor: 'white',
        padding: 12,
        borderRadius: 6,
        marginTop: 8,
        borderWidth: 1,
        borderColor: '#dee2e6',
    },
    input: {
        borderWidth: 1,
        borderColor: '#ced4da',
        borderRadius: 4,
        paddingHorizontal: 12,
        paddingVertical: 8,
        fontSize: 14,
        marginBottom: 8,
    },
    formButtons: {
        flexDirection: 'row',
        width: '100%',
    },
    saveButton: {
        flex: 1,
        backgroundColor: '#28a745',
        padding: 12,
        borderRadius: 4,
        alignItems: 'center',
        marginRight: 8,
    },
    saveButtonText: {
        color: 'white',
        fontWeight: '600',
        fontSize: 15,
    },
    cancelButton: {
        flex: 1,
        backgroundColor: '#6c757d',
        padding: 12,
        borderRadius: 4,
        alignItems: 'center',
    },
    cancelButtonText: {
        color: 'white',
        fontWeight: '600',
        fontSize: 15,
    },
    agentforceButton: {
        position: 'absolute',
        bottom: 30,
        right: 20,
        backgroundColor: '#0070f3',
        width: 60,
        height: 60,
        borderRadius: 30,
        justifyContent: 'center',
        alignItems: 'center',
        elevation: 5,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.25,
        shadowRadius: 3.84,
    },
    agentforceButtonText: {
        color: 'white',
        fontSize: 16,
        fontWeight: 'bold',
        textAlign: 'center',
    },
    agentforceButtonIcon: {
        width: 40,
        height: 40,
        resizeMode: 'contain',
    },
    agentforceButtonDisabled: {
        backgroundColor: '#cccccc',
    },
    editButton: {
        backgroundColor: '#0070f3',
        width: 32,
        height: 32,
        borderRadius: 16,
        justifyContent: 'center',
        alignItems: 'center',
    },
    editButtonText: {
        color: 'white',
        fontSize: 16,
        fontWeight: 'bold',
    },
    orgIdContainer: {
        backgroundColor: '#f8f9fa',
        padding: 15,
        marginTop: 5,
        marginHorizontal: 15,
        borderRadius: 8,
        borderWidth: 1,
        borderColor: '#e9ecef',
    },
    orgIdLabel: {
        fontSize: 16,
        fontWeight: '600',
        color: '#343a40',
        marginBottom: 8,
    },
    orgIdDisplay: {
        fontSize: 14,
        color: '#6c757d',
        fontFamily: 'monospace',
        backgroundColor: '#ffffff',
        padding: 12,
        borderRadius: 6,
        borderWidth: 1,
        borderColor: '#dee2e6',
    },
    userContextContainer: {
        backgroundColor: '#f8f9fa',
        padding: 15,
        marginTop: 5,
        marginHorizontal: 15,
        borderRadius: 8,
        borderWidth: 1,
        borderColor: '#e9ecef',
    },
    userContextLabel: {
        fontSize: 16,
        fontWeight: '600',
        color: '#343a40',
        marginBottom: 8,
    },
    userContextInputRow: {
        flexDirection: 'row',
        alignItems: 'flex-start',
    },
    userContextDisplayRow: {
        flexDirection: 'row',
        alignItems: 'flex-start',
    },
    userContextInput: {
        flex: 1,
        borderWidth: 1,
        borderColor: '#ced4da',
        borderRadius: 6,
        paddingHorizontal: 12,
        paddingVertical: 8,
        fontSize: 14,
        backgroundColor: 'white',
        marginRight: 8,
        minHeight: 40,
    },
    userContextDisplay: {
        flex: 1,
        fontSize: 14,
        color: '#495057',
        backgroundColor: 'transparent',
        paddingHorizontal: 12,
        paddingVertical: 8,
        marginRight: 8,
        minHeight: 40,
    },
    detailContainer: {
        flex: 1,
        backgroundColor: '#f8f9fa',
        padding: 15,
    },
    detailSection: {
        backgroundColor: 'white',
        padding: 15,
        marginBottom: 10,
        borderRadius: 8,
        borderWidth: 1,
        borderColor: '#e9ecef',
    },
    detailLabel: {
        fontSize: 12,
        fontWeight: '600',
        color: '#6c757d',
        marginBottom: 4,
        textTransform: 'uppercase',
    },
    detailValue: {
        fontSize: 16,
        color: '#212529',
    },
    recordIdRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 10,
    },
    recordIdValue: {
        flex: 1,
    },
    copyButton: {
        backgroundColor: '#0070f3',
        paddingHorizontal: 12,
        paddingVertical: 6,
        borderRadius: 4,
        borderWidth: 1,
        borderColor: '#0070f3',
    },
    copyButtonText: {
        color: 'white',
        fontSize: 12,
        fontWeight: '600',
    },
});

interface ContactDetailProps {
    route: RouteProp<RootStackParamList, 'ContactDetail'>;
}

class ContactDetailScreen extends React.Component<ContactDetailProps> {
    copyToClipboard = (text: string) => {
        Clipboard.setString(text);
        Alert.alert('Copied', 'Record ID copied to clipboard');
    }

    render() {
        const { contact } = this.props.route.params;

        return (
            <View style={styles.detailContainer}>
                <View style={styles.detailSection}>
                    <Text style={styles.detailLabel}>Name</Text>
                    <Text style={styles.detailValue}>{contact.Name}</Text>
                </View>

                <View style={styles.detailSection}>
                    <Text style={styles.detailLabel}>Record ID</Text>
                    <View style={styles.recordIdRow}>
                        <Text style={[styles.detailValue, styles.recordIdValue]}>{contact.Id}</Text>
                        <TouchableOpacity
                            style={styles.copyButton}
                            onPress={() => this.copyToClipboard(contact.Id)}
                        >
                            <Text style={styles.copyButtonText}>📋 Copy</Text>
                        </TouchableOpacity>
                    </View>
                </View>

                {contact.Email && (
                    <View style={styles.detailSection}>
                        <Text style={styles.detailLabel}>Email</Text>
                        <Text style={styles.detailValue}>{contact.Email}</Text>
                    </View>
                )}

                {contact.Phone && (
                    <View style={styles.detailSection}>
                        <Text style={styles.detailLabel}>Phone</Text>
                        <Text style={styles.detailValue}>{contact.Phone}</Text>
                    </View>
                )}

                {contact.MobilePhone && (
                    <View style={styles.detailSection}>
                        <Text style={styles.detailLabel}>Mobile</Text>
                        <Text style={styles.detailValue}>{contact.MobilePhone}</Text>
                    </View>
                )}

                {contact.Title && (
                    <View style={styles.detailSection}>
                        <Text style={styles.detailLabel}>Title</Text>
                        <Text style={styles.detailValue}>{contact.Title}</Text>
                    </View>
                )}

                {contact.Department && (
                    <View style={styles.detailSection}>
                        <Text style={styles.detailLabel}>Department</Text>
                        <Text style={styles.detailValue}>{contact.Department}</Text>
                    </View>
                )}

                {contact.Account?.Name && (
                    <View style={styles.detailSection}>
                        <Text style={styles.detailLabel}>Account</Text>
                        <Text style={styles.detailValue}>{contact.Account.Name}</Text>
                    </View>
                )}
            </View>
        );
    }
}

const Stack = createStackNavigator<RootStackParamList>();

function App(): JSX.Element {
    return (
        <NavigationContainer>
            <Stack.Navigator>
                <Stack.Screen
                    name="React Native Agentforce"
                    component={ContactListScreen}
                />
                <Stack.Screen
                    name="Settings"
                    component={SettingsScreen}
                    options={{ title: 'Settings' }}
                />
                <Stack.Screen
                    name="ContactDetail"
                    component={ContactDetailScreen}
                    options={{ title: 'Contact Details' }}
                />
            </Stack.Navigator>
        </NavigationContainer>
    );
}

export default App;
