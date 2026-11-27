import { describe, expect, test } from 'vitest';
import { ApiError } from '../api/client';
import { customerBody, customerProblems, customerProblemsFrom, sortCustomers, type Customer } from '../api/customers';

const MUSTER = { name: 'Muster GmbH', addressLine1: 'Musterweg 1', addressLine2: '1010 Wien', vatId: 'ATU00000000' };

describe('Firmenkunden', () => {
  test('Pflichtfelder und Längen wie am Tablet und am Server, gezählt ohne Leerzeichen vorn und hinten', () => {
    expect(customerProblems(MUSTER)).toEqual({});
    expect(customerProblems({ ...MUSTER, vatId: '' })).toEqual({});
    expect(customerProblems({ name: '  ', addressLine1: '', addressLine2: ' ', vatId: '' })).toEqual({
      name: 'Der Name muss 1 bis 80 Zeichen lang sein.',
      addressLine1: 'Die erste Adress-Zeile muss 1 bis 80 Zeichen lang sein.',
      addressLine2: 'Die zweite Adress-Zeile muss 1 bis 80 Zeichen lang sein.',
    });
    expect(customerProblems({ ...MUSTER, name: 'x'.repeat(80) })).toEqual({});
    expect(customerProblems({ ...MUSTER, name: ` ${'x'.repeat(80)} ` })).toEqual({});
    expect(Object.keys(customerProblems({ ...MUSTER, addressLine2: 'x'.repeat(81) }))).toEqual(['addressLine2']);
    expect(customerProblems({ ...MUSTER, vatId: 'A'.repeat(20) })).toEqual({});
    expect(customerProblems({ ...MUSTER, vatId: 'A'.repeat(21) })).toEqual({ vatId: 'Die UID darf höchstens 20 Zeichen lang sein.' });
  });

  test('an den Server geht der Text ohne Leerzeichen vorn und hinten, eine leere UID als null', () => {
    expect(customerBody({ name: ' Muster GmbH ', addressLine1: 'Musterweg 1 ', addressLine2: ' 1010 Wien', vatId: '  ' })).toEqual({
      name: 'Muster GmbH',
      addressLine1: 'Musterweg 1',
      addressLine2: '1010 Wien',
      vatId: null,
    });
    expect(customerBody({ ...MUSTER, vatId: ' ATU00000000 ' }).vatId).toBe('ATU00000000');
  });

  test('Fehler des Servers stehen beim Feld, andere über dem Formular', () => {
    const err = (code: string) => new ApiError(422, code, 'Satz');
    expect(customerProblemsFrom(err('name_invalid'))).toEqual({ name: 'Satz' });
    expect(customerProblemsFrom(err('address_line1_invalid'))).toEqual({ addressLine1: 'Satz' });
    expect(customerProblemsFrom(err('address_line2_invalid'))).toEqual({ addressLine2: 'Satz' });
    expect(customerProblemsFrom(err('vat_id_invalid'))).toEqual({ vatId: 'Satz' });
    expect(customerProblemsFrom(err('not_found'))).toEqual({ form: 'Satz' });
  });

  test('Liste: aktive zuerst, dann nach Name, wie der Server', () => {
    const c = (id: string, name: string, archived = false): Customer => ({ ...MUSTER, id, name, archived, vatId: null, updatedAt: '2026-11-27T10:00:00.000Z' });
    const sorted = sortCustomers([c('1', 'Zeta OG'), c('2', 'Alpha KG', true), c('3', 'Muster GmbH'), c('4', 'Ärztehaus GmbH')]);
    expect(sorted.map((x) => x.name)).toEqual(['Ärztehaus GmbH', 'Muster GmbH', 'Zeta OG', 'Alpha KG']);
  });
});
