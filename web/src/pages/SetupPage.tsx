import { useQueryClient } from '@tanstack/react-query';
import { useRef, useState, type FormEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { HOME, useSetup, useSetupToken } from '../api/auth';
import { Button } from '../ui/Button';
import { EmptyState } from '../ui/EmptyState';
import { LinkOffIcon } from '../ui/icons';
import { Skeleton } from '../ui/Skeleton';
import { TextField } from '../ui/TextField';
import { AuthLayout, FormAlert, formClass } from './AuthLayout';
import styles from './SetupPage.module.css';
import { emailProblem, MIN_PASSWORD_LENGTH, passwordLength } from './validate';

const LINK_INVALID = 'Dieser Link gilt nicht mehr. Bitte einen neuen anfordern.';

type Problems = { email?: string; password?: string; repeat?: string; form?: string };

/**
 * Konto mit dem Einmal-Schlüssel aus dem Link einrichten. Derselbe Weg setzt ein vergessenes Passwort neu:
 * gehört die E-Mail schon dem Anbieter, antwortet der Server 200 statt 201, und es geht genauso weiter.
 */
export function SetupPage() {
  const [params] = useSearchParams();
  const token = params.get('token') ?? '';
  const check = useSetupToken(token);
  const queryClient = useQueryClient();
  const setup = useSetup();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [repeat, setRepeat] = useState('');
  const [problems, setProblems] = useState<Problems>({});
  const emailRef = useRef<HTMLInputElement>(null);
  const passwordRef = useRef<HTMLInputElement>(null);
  const repeatRef = useRef<HTMLInputElement>(null);

  if (check.isPending) {
    return (
      <AuthLayout title="Konto einrichten">
        <Skeleton lines={5} label="Link wird geprüft" />
      </AuthLayout>
    );
  }

  if (check.isError) {
    return (
      <AuthLayout title="Konto einrichten">
        <EmptyState
          title="Der Link lässt sich gerade nicht prüfen"
          text={check.error.message}
          action={
            <Button variant="secondary" onClick={() => void check.refetch()}>
              Nochmal versuchen
            </Button>
          }
        />
      </AuthLayout>
    );
  }

  if (!check.data) {
    return (
      <AuthLayout title="Konto einrichten" footer={<Link to="/anmelden">Zur Anmeldung</Link>}>
        <p className={styles.invalid}>
          <LinkOffIcon size={22} className={styles.invalidIcon} />
          <span>{LINK_INVALID}</span>
        </p>
      </AuthLayout>
    );
  }

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (setup.isPending) return;
    const next: Problems = {
      email: emailProblem(email),
      password:
        passwordLength(password) < MIN_PASSWORD_LENGTH ? 'Das Passwort braucht mindestens 10 Zeichen.' : undefined,
      repeat:
        repeat === ''
          ? 'Bitte gib das Passwort noch einmal ein.'
          : repeat !== password
            ? 'Die beiden Passwörter stimmen nicht überein.'
            : undefined,
    };
    setProblems(next);
    if (next.email) return emailRef.current?.focus();
    if (next.password) return passwordRef.current?.focus();
    if (next.repeat) return repeatRef.current?.focus();

    setup.mutate(
      { token, email: email.trim(), password },
      {
        onSuccess: () => void navigate(HOME, { replace: true }),
        onError: (err) => {
          switch (err.code) {
            case 'setup_invalid':
              queryClient.setQueryData(['setup-token', token], false);
              break;
            case 'email_taken':
            case 'email_invalid':
              setProblems({ email: err.message });
              emailRef.current?.focus();
              break;
            case 'password_too_short':
              setProblems({ password: err.message });
              passwordRef.current?.focus();
              break;
            default:
              setProblems({ form: err.message });
          }
        },
      },
    );
  };

  return (
    <AuthLayout
      title="Konto einrichten"
      lead="Trag deine E-Mail-Adresse ein und wähl ein Passwort. Damit meldest du dich ab jetzt an."
    >
      <form className={formClass} onSubmit={onSubmit} noValidate>
        <TextField
          ref={emailRef}
          label="E-Mail"
          type="email"
          name="email"
          autoComplete="username"
          inputMode="email"
          autoCapitalize="none"
          spellCheck={false}
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          error={problems.email}
          autoFocus
        />
        <TextField
          ref={passwordRef}
          label="Passwort"
          type="password"
          name="new-password"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          error={problems.password}
          hint={problems.password ? undefined : 'Mindestens 10 Zeichen. Ein Satz, den du dir merken kannst, ist gut.'}
        />
        <TextField
          ref={repeatRef}
          label="Passwort wiederholen"
          type="password"
          name="repeat-password"
          autoComplete="new-password"
          value={repeat}
          onChange={(e) => setRepeat(e.target.value)}
          error={problems.repeat}
        />
        {problems.form && <FormAlert>{problems.form}</FormAlert>}
        <Button type="submit" variant="primary" busy={setup.isPending}>
          Konto anlegen
        </Button>
      </form>
    </AuthLayout>
  );
}
