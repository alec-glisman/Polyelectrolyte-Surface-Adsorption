import argparse
from datetime import datetime
import math


def extract_section(lines, start_index):
    section = []
    for j in range(start_index + 1, len(lines)):
        line = lines[j].strip()
        if line == "":
            break
        elif line.startswith(";"):
            continue
        section.append(line)
    return section


def header_to_xml():
    xml = "  <Info>\n"
    xml += "    <DateGenerated>"
    xml += datetime.now().strftime("%Y-%m-%d")
    xml += "</DateGenerated>\n"
    xml += "  </Info>\n"
    return xml


def atom_types() -> str:
    return """  <AtomTypes>
    <Type element="C" name="c" class="c" mass="12.01"/>
    <Type element="C" name="c3" class="c3" mass="12.01"/>
    <Type element="H" name="h1" class="h1" mass="1.008"/>
    <Type element="H" name="hc" class="hc" mass="1.008"/>
    <Type element="H" name="ho" class="ho" mass="1.008"/>
    <Type element="O" name="o" class="o" mass="16.00"/>
    <Type element="O" name="oc" class="oc" mass="16.00"/>
    <Type element="O" name="oh" class="oh" mass="16.00"/>
    <Type element="O" name="os" class="os" mass="16.00"/>
    <Type element="C" name="cx" class="cx" mass="12.01"/>
    <Type element="O" name="ox" class="ox" mass="16.00"/>
    <Type element="Cl" name="cl" class="cl" mass="35.45"/>
    <Type element="Ca" name="c0" class="c0" mass="40.08"/>
    <Type element="Na" name="na" class="na" mass="22.99"/>
  </AtomTypes>
"""


def bonded_interactions(filename: str) -> str:

    def convert_bonds_to_xml(bonds):
        xml = "  <HarmonicBondForce>\n"
        for bond in bonds:
            tokens = bond.split()
            if int(tokens[2]) != 1:
                raise ValueError("Only harmonic bonds are supported")

            xml += "    <Bond"
            xml += f" class1='{tokens[0]}'"
            xml += f" class2='{tokens[1]}'"
            xml += f" length='{float(tokens[3])}'"
            xml += f" k='{float(tokens[4])}'"
            xml += "/>\n"
        xml += "  </HarmonicBondForce>\n"
        return xml

    def convert_angles_to_xml(angles):
        xml = "  <HarmonicAngleForce>\n"
        for angle in angles:
            tokens = angle.split()
            if int(tokens[3]) != 1:
                raise ValueError("Only harmonic angles are supported")

            xml += "    <Angle"
            xml += f" class1='{tokens[0]}'"
            xml += f" class2='{tokens[1]}'"
            xml += f" class3='{tokens[2]}'"
            xml += f" angle='{math.radians(float(tokens[4]))}'"
            xml += f" k='{float(tokens[5])}'"
            xml += "/>\n"
        xml += "  </HarmonicAngleForce>\n"
        return xml

    def convert_dihedrals_to_xml(dihedrals):
        xml = "  <RBTorsionForce>\n"
        for dihedral in dihedrals:
            tokens = dihedral.split()
            if int(tokens[4]) != 3:
                raise ValueError("Only proper dihedrals are supported")

            xml += "    <Proper"
            xml += f" class1='{tokens[0]}'"
            xml += f" class2='{tokens[1]}'"
            xml += f" class3='{tokens[2]}'"
            xml += f" class4='{tokens[3]}'"
            xml += f" c0='{float(tokens[5])}'"
            xml += f" c1='{float(tokens[6])}'"
            xml += f" c2='{float(tokens[7])}'"
            xml += f" c3='{float(tokens[8])}'"
            xml += f" c4='{float(tokens[9])}'"
            xml += f" c5='{float(tokens[10])}'"
            xml += "/>\n"

        xml += "  </RBTorsionForce>\n"
        return xml

    def convert_impropers_to_xml(impropers):
        xml = "  <PeriodicTorsionForce ordering='amber'>\n"
        for improper in impropers:
            tokens = improper.split()
            if int(tokens[4]) != 1:
                raise ValueError("Only improper dihedrals are supported")

            xml += "    <Improper"
            xml += f" class1='{tokens[0]}'"
            xml += f" class2='{tokens[1]}'"
            xml += f" class3='{tokens[2]}'"
            xml += f" class4='{tokens[3]}'"
            xml += f" periodicity1='{tokens[7]}'"
            xml += f" phase1='{math.radians(float(tokens[5]))}'"
            xml += f" k1='{float(tokens[6])}'"
            xml += "/>\n"

        xml += "  </PeriodicTorsionForce>\n"
        return xml

    with open(filename, "r", encoding="utf-8") as f:
        lines = f.readlines()

    bonds = []
    angles = []
    dihedrals = []
    impropers = []
    for i, line in enumerate(lines):
        line = line.strip()
        if line == "[ bondtypes ]":
            bonds = extract_section(lines, i)
        elif line == "[ angletypes ]":
            angles = extract_section(lines, i)
        elif line == "[ dihedraltypes ] ; propers":
            dihedrals = extract_section(lines, i)
        elif line == "[ dihedraltypes ]  ; impropers":
            impropers = extract_section(lines, i)

    xml = convert_bonds_to_xml(bonds)
    xml += convert_angles_to_xml(angles)
    xml += convert_dihedrals_to_xml(dihedrals)
    xml += convert_impropers_to_xml(impropers)
    return xml


def nonbonded_interactions(filename: str) -> str:
    with open(filename, "r", encoding="utf-8") as f:
        lines = f.readlines()

    xml = "  <NonbondedForce coulomb14scale='0.8333333333333334' lj14scale='0.5'>\n"
    xml += "    <UseAttributeFromResidue name='charge'/>\n"

    for i, line in enumerate(lines):
        line = line.strip()
        if line == "[ atomtypes ]":
            atomtypes = extract_section(lines, i)
            for atomtype in atomtypes:
                tokens = atomtype.split()
                xml += "    <Atom"
                xml += f" class='{tokens[0]}'"
                xml += f" sigma='{float(tokens[5])}'"
                xml += f" epsilon='{float(tokens[6])}'"
                xml += "/>\n"

    xml += "  <NonbondedForce>\n"
    return xml


def main(directory_force_field: str):
    xml = "<ForceField>\n"
    xml += header_to_xml()
    xml += atom_types()
    xml += bonded_interactions(f"{directory_force_field}/ffbonded.itp")
    xml += nonbonded_interactions(f"{directory_force_field}/ffnonbonded.itp")
    # TODO: add residue information
    # TODO: add small molecule information
    xml += "</ForceField>\n"

    # write xml to file
    with open("gaff_eccr.xml", "w", encoding="utf-8") as f:
        f.write(xml)


if __name__ == "__main__":
    argparser = argparse.ArgumentParser()
    argparser.add_argument("directory_force_field", type=str)
    args = argparser.parse_args()

    main(args.directory_force_field)
