import type { AgentforceContextVariable } from 'react-native-agentforce';
import {
  getContextVariables,
  setContextVariables,
  clearContextVariables,
} from '../ContextVariablesStore';

// Reset store between tests by clearing both agent types
beforeEach(() => {
  clearContextVariables('service');
  clearContextVariables('employee');
});

const textVar = (name: string, value: string): AgentforceContextVariable => ({
  name,
  type: 'Text',
  value,
});

describe('ContextVariablesStore', () => {
  it('returns empty array initially for each agent type', () => {
    expect(getContextVariables('service')).toEqual([]);
    expect(getContextVariables('employee')).toEqual([]);
  });

  it('stores and retrieves variables for service agent', () => {
    const variables: AgentforceContextVariable[] = [
      { name: 'userId', type: 'Text', value: '005xx0000001234' },
      { name: 'score', type: 'Number', value: 95.5 },
    ];

    setContextVariables('service', variables);

    expect(getContextVariables('service')).toEqual(variables);
  });

  it('stores and retrieves variables for employee agent', () => {
    const variables: AgentforceContextVariable[] = [
      { name: 'isVIP', type: 'Boolean', value: true },
    ];

    setContextVariables('employee', variables);

    expect(getContextVariables('employee')).toEqual(variables);
  });

  it('keeps service and employee stores independent', () => {
    const serviceVars = [textVar('svcVar', 'svc')];
    const employeeVars = [textVar('empVar', 'emp')];

    setContextVariables('service', serviceVars);
    setContextVariables('employee', employeeVars);

    expect(getContextVariables('service')).toEqual(serviceVars);
    expect(getContextVariables('employee')).toEqual(employeeVars);
  });

  it('clears variables for a specific agent type without affecting the other', () => {
    setContextVariables('service', [textVar('a', '1')]);
    setContextVariables('employee', [textVar('b', '2')]);

    clearContextVariables('service');

    expect(getContextVariables('service')).toEqual([]);
    expect(getContextVariables('employee')).toEqual([textVar('b', '2')]);
  });

  it('returns a copy, not a reference to internal state', () => {
    setContextVariables('service', [textVar('x', 'val')]);

    const result = getContextVariables('service');
    result.push(textVar('mutated', 'bad'));

    expect(getContextVariables('service')).toHaveLength(1);
    expect(getContextVariables('service')[0].name).toBe('x');
  });

  it('does not allow external mutation via set input array', () => {
    const input: AgentforceContextVariable[] = [textVar('original', 'val')];
    setContextVariables('service', input);

    input.push(textVar('sneaky', 'bad'));

    expect(getContextVariables('service')).toHaveLength(1);
  });

  it('overwrites previous variables on set', () => {
    setContextVariables('service', [textVar('first', '1')]);
    setContextVariables('service', [{ name: 'second', type: 'Number', value: 2 }]);

    const result = getContextVariables('service');
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('second');
  });
});
