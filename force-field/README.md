# Gromacs Force Fields

The [`force-field`](.//force-field) directory contains files that are used to build Gromacs topologies and parameterize molecules.

We make heavy use of the [AMBER99-SB*-ILDN-Q force field](./bestlab-force-fields/gromacs_format/amber99sb-star-ildn-q.ff) in our simulations of poly(aspartic acid) and poly(glutamic acid).
This field is highly optimized and has better backbone dihedral costs (SB\*) and side-chain torsion costs (ILDN) than the base field (ff99).
For more information on this force field, and references for its development, please see the [README inside the Best Lab](https://github.com/bestlab/force_fields/blob/master/README) repository.

The synthetic polymer force field is based on parameters from
[Mintis and Mavrantzas (2019)](https://doi.org/10.1021/acs.jpcb.9b01696), which used the General Amber Force Field (GAFF).
We have converted the tables of parameters into a force field named [`gaff.ff`](./eccrpa-force-fields/gaff.ff) that can be used with Gromacs.

Small ion parameters, such as sodium, calcium, and chlorine, are taken from the Jungwirth group's ECCR model fittings.
Sodium ion parameters are found in:
> Kohagen, Miriam, Philip E. Mason, and Pavel Jungwirth. "Accounting for electronic polarization effects in aqueous sodium chloride via molecular dynamics aided by neutron scattering." The Journal of Physical Chemistry B 120.8 (2016): 1454-1460.

Calcium and chlorine ion parameters are found in:
> Martinek, Tomas, et al. "Calcium ions in aqueous solutions: Accurate force field description aided by ab initio molecular dynamics and neutron scattering." The Journal of chemical physics 148.22 (2018): 222813

The carbonate ion parameters come from a combination of sources. 
Partial charges are taken from the same RESP fitting as the polymer parameters and are scaled by 0.75 using the ECC method.
We start by treating the carbonate oxygen and carbon atoms as `o` and `c2` atom types in GAFF.
The `o` atom type is used for carbonyl oxygens, and the `c2` atom type is used for sp2 hybridized carbons.
We then alter the equilibrium bond lengths and angles to match experimental values (ie. bond angle of 120 degrees).
Finally, we refit the Lennard-Jones parameters to reproduce the correct calcium-carbonate potential of mean force in water.


Water is modeled using SPC/E, as it offers a good balance of physical performance and computational accuracy.
Future work may investigate polarizable water models.

Force field parameter generation is handled by the [`parameter-generation`](./parameter-generation) directory.
