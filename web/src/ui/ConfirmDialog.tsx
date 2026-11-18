import type { ReactNode } from 'react';
import { Button } from './Button';
import { Dialog } from './Dialog';

export type ConfirmDialogProps = {
  open: boolean;
  title: string;
  text: ReactNode;
  confirmLabel: string;
  /** Gefährliche Aktion: der Knopf ist rot umrandet statt petrol. */
  danger?: boolean;
  onConfirm: () => void;
  onClose: () => void;
};

/** Rückfrage vor etwas, das sich nicht rückgängig machen lässt. Den Fehler zeigt die Seite nach dem Schließen als Hinweis. */
export function ConfirmDialog({ open, title, text, confirmLabel, danger = false, onConfirm, onClose }: ConfirmDialogProps) {
  return (
    <Dialog
      title={title}
      open={open}
      onClose={onClose}
      actions={
        <>
          <Button variant="quiet" onClick={onClose}>
            Abbrechen
          </Button>
          <Button variant={danger ? 'danger' : 'primary'} onClick={onConfirm}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      <p>{text}</p>
    </Dialog>
  );
}
