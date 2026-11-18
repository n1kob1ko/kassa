import { useRef, useState, type FormEvent } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router';
import { afterLoginPath, useLogin, useMe } from '../api/auth';
import { Button } from '../ui/Button';
import { TextField } from '../ui/TextField';
import { AuthLayout, FormAlert, formClass } from './AuthLayout';
import { emailProblem, waitText } from './validate';

type Problems = { email?: string; password?: string; form?: string };

export function LoginPage() {
  const me = useMe();
  const login = useLogin();
  const navigate = useNavigate();
  const location = useLocation();
  const target = afterLoginPath((location.state as { from?: unknown } | null)?.from);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [problems, setProblems] = useState<Problems>({});
  const emailRef = useRef<HTMLInputElement>(null);
  const passwordRef = useRef<HTMLInputElement>(null);

  if (me.data) return <Navigate to={target} replace />;

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (login.isPending) return;
    const next: Problems = {
      email: emailProblem(email),
      password: password === '' ? 'Bitte gib dein Passwort ein.' : undefined,
    };
    setProblems(next);
    if (next.email) return emailRef.current?.focus();
    if (next.password) return passwordRef.current?.focus();

    login.mutate(
      { email: email.trim(), password },
      {
        onSuccess: () => void navigate(target, { replace: true }),
        onError: (err) => {
          if (err.code === 'login_failed') {
            setProblems({ form: 'E-Mail oder Passwort stimmt nicht.' });
            passwordRef.current?.select();
          } else if (err.code === 'too_many_attempts') {
            setProblems({ form: waitText(err.retryAfterSeconds) });
          } else {
            setProblems({ form: err.message });
          }
        },
      },
    );
  };

  return (
    <AuthLayout
      title="Anmelden"
      lead="Mit deiner E-Mail-Adresse und deinem Passwort."
      footer="Passwort vergessen? Lass dir einen neuen Link zum Einrichten schicken."
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
          name="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          error={problems.password}
        />
        {problems.form && <FormAlert>{problems.form}</FormAlert>}
        <Button type="submit" variant="primary" busy={login.isPending}>
          Anmelden
        </Button>
      </form>
    </AuthLayout>
  );
}
