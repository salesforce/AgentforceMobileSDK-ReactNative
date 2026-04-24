import type { AgentforceContextVariable } from 'react-native-agentforce';
import {
  getContextVariables,
  setContextVariables,
  clearContextVariables,
} from '../ContextVariablesStore';

beforeEach(() => {
  clearContextVariables();
});

const textVar = (name: string, value: string): AgentforceContextVariable => ({
  name,
  type: 'Text',
  value,
});

describe('ContextVariablesStore', () => {
  it('returns empty array initially', () => {
    expect(getContextVariables()).toEqual([]);
  });

  it('stores and retrieves variables', () => {
    const variables: AgentforceContextVariable[] = [
      { name: 'isVIP', type: 'Boolean', value: true },
      { name: 'score', type: 'Number', value: 95.5 },
    ];

    setContextVariables(variables);

    expect(getContextVariables()).toEqual(variables);
  });

  it('clears variables', () => {
    setContextVariables([textVar('a', '1')]);

    clearContextVariables();

    expect(getContextVariables()).toEqual([]);
  });

  it('returns a copy, not a reference to internal state', () => {
    setContextVariables([textVar('x', 'val')]);

    const result = getContextVariables();
    result.push(textVar('mutated', 'bad'));

    expect(getContextVariables()).toHaveLength(1);
    expect(getContextVariables()[0].name).toBe('x');
  });

  it('does not allow external mutation via set input array', () => {
    const input: AgentforceContextVariable[] = [textVar('original', 'val')];
    setContextVariables(input);

    input.push(textVar('sneaky', 'bad'));

    expect(getContextVariables()).toHaveLength(1);
  });

  it('overwrites previous variables on set', () => {
    setContextVariables([textVar('first', '1')]);
    setContextVariables([{ name: 'second', type: 'Number', value: 2 }]);

    const result = getContextVariables();
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('second');
  });
});
