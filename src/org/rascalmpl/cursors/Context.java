package org.rascalmpl.cursors;

import org.eclipse.imp.pdb.facts.IValue;

public abstract class Context {

	public abstract IValue up(IValue focus);
}
